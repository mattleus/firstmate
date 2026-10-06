import { spawn } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import { eventMatchesRoot } from "./lib/fm-event-location.js";

const handledSessions = new Set();

function runProcess(command, args) {
  return new Promise((resolveResult) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.on("error", () => resolveResult({ code: 0, stdout: "" }));
    child.on("close", (code) => resolveResult({ code: code ?? 0, stdout }));
  });
}

function resolvePath(anchor) {
  try {
    return realpathSync(anchor);
  } catch {
    return resolve(anchor);
  }
}

async function resolveRoot(anchor) {
  if (!anchor) return "";
  const result = await runProcess("git", ["-C", anchor, "rev-parse", "--show-toplevel"]);
  const root = result.stdout.trim();
  if (result.code === 0 && root) return root;
  return resolvePath(anchor);
}

export default {
  id: "fm-primary-sessionstart-nudge",
  setup(ctx) {
    const controller = new AbortController();
    void (async () => {
      const root = await resolveRoot(ctx.location.directory);
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        if (event.type !== "session.created") continue;
        if (!eventMatchesRoot(event, root)) continue;
        const sessionID = event.durable?.aggregateID ?? event.data?.sessionID;
        if (!sessionID || handledSessions.has(sessionID) || !root) continue;
        handledSessions.add(sessionID);

        const result = await runProcess(`${root}/bin/fm-sessionstart-nudge.sh`, []);
        const nudge = result.code === 0 ? result.stdout.trim() : "";
        if (!nudge) continue;

        try {
          await ctx.session.prompt({ sessionID, text: nudge });
        } catch {}
      }
    })().catch(() => {});
    return () => controller.abort();
  },
};
