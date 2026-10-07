#!/usr/bin/env bash
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLUGIN="$ROOT/.opencode/plugins/fm-primary-watch-arm.js"
TMP_ROOT=$(fm_test_tmproot fm-opencode-primary-watch-arm)

make_fixture() {
  local repo="$TMP_ROOT/$1" home="$TMP_ROOT/$1-home"
  mkdir -p "$repo/bin" "$home/state" "$home/config"
  git init -q "$repo"
  : > "$repo/AGENTS.md"
  cp "$ROOT/bin/fm-wake-lib.sh" "$ROOT/bin/fm-path-lib.sh" "$repo/bin/"
  : > "$home/state/task.meta"
  printf '%s\t%s\n' "$repo" "$home"
}

test_prompt_failure_publishes_durable_diagnostics() {
  local fixture repo home log stop out status
  fixture=$(make_fixture prompt-failure)
  repo=${fixture%%$'\t'*}
  home=${fixture#*$'\t'}
  log="$TMP_ROOT/prompt-failure.log"
  stop="$TMP_ROOT/prompt-failure.stop"
  cat > "$repo/bin/fm-watch-arm.sh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --handling-delivered ]; then exit 0; fi
count=$(test -f "$FM_ARM_LOG" && wc -l < "$FM_ARM_LOG" || printf 0)
printf 'arm=%s\n' "$$" >> "$FM_ARM_LOG"
printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
if [ "$count" -eq 0 ]; then
  printf 'signal: terminal outcome\n'
  exit 0
fi
trap 'exit 0' TERM INT
while [ ! -e "$FM_STOP_FILE" ]; do sleep 0.02; done
SH
  chmod +x "$repo/bin/fm-watch-arm.sh"
  out=$(PLUGIN="$PLUGIN" WORKTREE="$repo" FM_HOME="$home" FM_ARM_LOG="$log" FM_STOP_FILE="$stop" FM_WATCH_REARM_RETRY_BASE_MS=5 FM_WATCH_REARM_RETRY_MAX_MS=10 node 2>&1 <<'EOF'
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const mod = await import(pathToFileURL(process.env.PLUGIN).href);
const client = { session: { promptAsync: async () => { throw new Error("prompt unavailable"); } } };
writeFileSync(`${process.env.FM_HOME}/state/.lock`, `${process.pid}\n`);
const hooks = mod.default.setup({
  location: { directory: process.env.WORKTREE },
  event: { subscribe: async function* () { yield { type: "session.idle", data: { sessionID: "session-test" } }; await new Promise(() => {}); } },
});
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const queuePath = `${process.env.FM_HOME}/state/.wake-queue`;
const countOccurrences = (text, needle) => text.split(needle).length - 1;
for (let i = 0; i < 500 && !existsSync(`${process.env.FM_ARM_LOG}`); i += 1) await sleep(10);
let queue = "";
for (let i = 0; i < 500; i += 1) {
  if (existsSync(queuePath)) {
    queue = readFileSync(queuePath, "utf8");
    if (queue.includes("prompt delivery failed")) break;
  }
  await sleep(10);
}
if (!queue.includes("OpenCode watcher continuity failure")) throw new Error(`missing durable prompt failure: ${queue}`);
if (!queue.includes("could not deliver an actionable wake")) throw new Error(`missing wake failure detail: ${queue}`);
if (!queue.includes("prompt delivery failed")) throw new Error(`missing durable delivery failure: ${queue}`);
const rows = queue.trim().split("\n");
if (rows.length !== 2) throw new Error(`expected each failure exactly once: ${queue}`);
if (countOccurrences(queue, "could not deliver an actionable wake") !== 1) throw new Error(`prompt failure was repeated: ${queue}`);
if (countOccurrences(queue, "prompt delivery failed") !== 1) throw new Error(`delivery failure was repeated: ${queue}`);
writeFileSync(process.env.FM_STOP_FILE, "stop\n");
hooks();
EOF
  )
  status=$?
  expect_code 0 "$status" "OpenCode prompt failures must publish durable diagnostics: $out"
  [ -z "$out" ] || fail "OpenCode prompt failure test printed output: $out"
  pass "OpenCode prompt failure publishes durable diagnostics"
}

test_plugin_initialization_failure_publishes_durable_diagnostic() {
  local fixture repo home out status
  fixture=$(make_fixture initialization-failure)
  repo=${fixture%%$'\t'*}
  home=${fixture#*$'\t'}
  out=$(PLUGIN="$PLUGIN" WORKTREE="$repo" FM_HOME="$home" node 2>&1 <<'EOF'
import { existsSync, readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const mod = await import(pathToFileURL(process.env.PLUGIN).href);
mod.default.setup({
  location: { directory: process.env.WORKTREE },
  event: { subscribe: async function* () { throw new Error("event stream unavailable"); } },
});
for (let i = 0; i < 500 && !existsSync(`${process.env.FM_HOME}/state/.wake-queue`); i += 1) await new Promise((resolve) => setTimeout(resolve, 10));
const queue = readFileSync(`${process.env.FM_HOME}/state/.wake-queue`, "utf8");
if (!queue.includes("plugin initialization failed")) throw new Error(`missing durable initialization failure: ${queue}`);
EOF
  )
  status=$?
  expect_code 0 "$status" "OpenCode plugin initialization failures must be durable: $out"
  [ -z "$out" ] || fail "OpenCode initialization failure test printed output: $out"
  pass "OpenCode plugin initialization failure publishes a durable diagnostic"
}

test_missing_successor_surfaces_durable_terminal_failure() {
  local fixture repo home log out status
  fixture=$(make_fixture missing-successor)
  repo=${fixture%%$'\t'*}
  home=${fixture#*$'\t'}
  log="$TMP_ROOT/missing-successor.log"
  cat > "$repo/bin/fm-watch-arm.sh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --handling-delivered ]; then exit 0; fi
count=$(test -f "$FM_ARM_LOG" && wc -l < "$FM_ARM_LOG" || printf 0)
printf 'arm=%s\n' "$$" >> "$FM_ARM_LOG"
if [ "$count" -eq 0 ]; then
  printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
  printf 'signal: terminal outcome\n'
else
  printf 'watcher: FAILED - successor unavailable\n' >&2
  exit 1
fi
SH
  chmod +x "$repo/bin/fm-watch-arm.sh"
  out=$(PLUGIN="$PLUGIN" WORKTREE="$repo" FM_HOME="$home" FM_ARM_LOG="$log" FM_WATCH_REARM_RETRY_BASE_MS=5 FM_WATCH_REARM_RETRY_MAX_MS=10 FM_WATCH_REARM_RETRY_LIMIT=1 node 2>&1 <<'EOF'
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const mod = await import(pathToFileURL(process.env.PLUGIN).href);
let prompt = "";
const client = { session: { promptAsync: async (request) => { prompt = request.body.parts[0].text; } } };
writeFileSync(`${process.env.FM_HOME}/state/.lock`, `${process.pid}\n`);
mod.default.setup({
  location: { directory: process.env.WORKTREE },
  event: { subscribe: async function* () { yield { type: "session.idle", data: { sessionID: "session-test" } }; await new Promise(() => {}); } },
});
for (let i = 0; i < 500 && !existsSync(`${process.env.FM_HOME}/state/.wake-queue`); i += 1) await new Promise((resolve) => setTimeout(resolve, 10));
const queue = readFileSync(`${process.env.FM_HOME}/state/.wake-queue`, "utf8");
if (!queue.includes("could not restore watcher continuity after 1 retries")) throw new Error(`missing durable successor failure: ${queue}`);
EOF
  )
  status=$?
  expect_code 0 "$status" "OpenCode missing successors must surface a durable terminal failure: $out"
  [ -z "$out" ] || fail "OpenCode missing successor test printed output: $out"
  pass "OpenCode missing successor surfaces a durable terminal failure"
}

test_dedupe_marker_expiry_republishes_identical_diagnostic() {
  local fixture repo home out status
  fixture=$(make_fixture dedupe-expiry)
  repo=${fixture%%$'\t'*}
  home=${fixture#*$'\t'}
  out=$(PLUGIN="$PLUGIN" WORKTREE="$repo" FM_HOME="$home" node 2>&1 <<'EOF'
import { existsSync, readFileSync, readdirSync, utimesSync } from "node:fs";
import { pathToFileURL } from "node:url";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const mod = await import(pathToFileURL(process.env.PLUGIN).href);
const setupPlugin = () => mod.default.setup({
  location: { directory: process.env.WORKTREE },
  event: { subscribe: async function* () { throw new Error("event stream unavailable"); } },
});
const stateDir = `${process.env.FM_HOME}/state`;
const queuePath = `${stateDir}/.wake-queue`;
const readRows = () => (existsSync(queuePath) ? readFileSync(queuePath, "utf8").trim().split("\n").filter(Boolean) : []);
setupPlugin();
for (let i = 0; i < 500 && readRows().length === 0; i += 1) await sleep(10);
if (!readRows()[0]?.includes("plugin initialization failed")) throw new Error("missing first durable initialization failure");
setupPlugin();
await sleep(1500);
if (readRows().length !== 1) throw new Error(`identical failure inside the dedupe window was repeated: ${readRows().join("\n")}`);
const markers = readdirSync(stateDir).filter((name) => name.startsWith(".opencode-watch-diagnostic-"));
if (markers.length !== 1) throw new Error(`expected one dedupe marker: ${markers.join(", ")}`);
const stale = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
utimesSync(`${stateDir}/${markers[0]}`, stale, stale);
setupPlugin();
for (let i = 0; i < 500 && readRows().length < 2; i += 1) await sleep(10);
const rows = readRows();
if (rows.length !== 2 || !rows[1].includes("plugin initialization failed")) {
  throw new Error(`expired marker did not republish the recurring failure: ${rows.join("\n")}`);
}
EOF
  )
  status=$?
  expect_code 0 "$status" "OpenCode diagnostic dedupe markers must expire: $out"
  [ -z "$out" ] || fail "OpenCode dedupe expiry test printed output: $out"
  pass "OpenCode dedupe marker expiry republishes an identical diagnostic"
}

test_prompt_failure_publishes_durable_diagnostics
test_plugin_initialization_failure_publishes_durable_diagnostic
test_missing_successor_surfaces_durable_terminal_failure
test_dedupe_marker_expiry_republishes_identical_diagnostic
