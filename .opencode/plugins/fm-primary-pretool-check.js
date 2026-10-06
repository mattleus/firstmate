import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import { spawn } from "node:child_process";

// PreToolUse seatbelt for OpenCode: the arm mechanism itself lives entirely in
// fm-primary-watch-arm.js (a plugin-owned child process, never a model tool
// call), so the residual risk here is the AGENT shelling `bin/fm-watch-arm.sh`
// wrong through its own shell tool - the anti-pattern bin/fm-arm-pretool-check.sh
// guards against (see that script's header and docs/arm-pretool-check.md).
// Blocking contract: throwing inside the hook stops the command and surfaces
// the thrown message as the failed tool result; validated live against
// OpenCode 2.0.23's V2 `ctx.tool.hook("execute.before")` on 2026-10-05,
// superseding the 2026-07-09 V1-hook validation in docs/arm-pretool-check.md.

function runProcess(command, args) {
  return new Promise((resolvePromise) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", () => resolvePromise({ code: 0, stdout: "", stderr: "" }));
    child.on("close", (code) => resolvePromise({ code: code ?? 0, stdout, stderr }));
  });
}

async function resolveRoot(anchor) {
  if (!anchor) return "";
  const result = await runProcess("git", ["-C", anchor, "rev-parse", "--show-toplevel"]);
  const root = result.stdout.trim();
  if (result.code === 0 && root) return root;
  try {
    return realpathSync(anchor);
  } catch {
    return resolve(anchor);
  }
}

// The tool is named "shell" in OpenCode V2 ("bash" in V1); both are matched so
// the guard keeps working across adapter naming.

export default {
  id: "fm-primary-pretool-check",
  async setup(ctx) {
    const root = await resolveRoot(ctx.location.directory);

    await ctx.tool.hook("execute.before", async (event) => {
      if (!root || (event.tool !== "shell" && event.tool !== "bash")) return;
      const command = event.input?.command;
      if (!command || typeof command !== "string") return;

      const result = await runProcess(`${root}/bin/fm-arm-pretool-check.sh`, ["--command", command]);
      if (result.code !== 2) return;

      const reason = result.stderr.trim() || "denied by the watcher-arm PreToolUse seatbelt";
      throw new Error(reason);
    });
  },
};
