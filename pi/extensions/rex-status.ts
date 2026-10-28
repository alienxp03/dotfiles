// Rex Program Status Protocol: https://www.superlogical.com/rex/docs/build/program-status
import { writeSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type State = "idle" | "working" | "blocked" | "done" | "error" | "clear";

export default function (pi: ExtensionAPI) {
  let enabled = false;
  let running = false;
  let failed = false;
  let prompts = 0;
  let settled: State = "idle";
  let lastReport = "";
  let originalWrite: typeof process.stdout.write | undefined;
  let wrappedWrite: typeof process.stdout.write | undefined;
  let unsubscribeInput: (() => void) | undefined;

  function setFocusReporting(active: boolean) {
    try {
      writeSync(process.stdout.fd, active ? "\x1b[?1004h" : "\x1b[?1004l");
    } catch {
      // Terminal shutdown can close the descriptor before cleanup finishes.
    }
  }

  function guardPromptMarkers() {
    originalWrite = process.stdout.write;
    const write = originalWrite;
    wrappedWrite = ((chunk: string | Uint8Array, ...args: any[]) => {
      // Pi marks transcript messages as shell prompts. Rex drops working/blocked
      // records on OSC 133 A, even though the agent is still running.
      if (enabled && typeof chunk === "string") {
        chunk = chunk.replace(/\x1b\]133;[ABC](?:\x07|\x1b\\)/g, "");
      }
      return write.call(process.stdout, chunk, ...args);
    }) as typeof process.stdout.write;
    process.stdout.write = wrappedWrite;
  }

  function report(state: State, kind?: "permission" | "question") {
    if (!enabled) return;
    const body = `state=${state}:id=pi:app=pi${kind ? `:kind=${kind}` : ""}`;
    if (body === lastReport) return;
    // Send terminal control bytes directly; stdout.write can be redirected by Pi or extensions.
    try {
      writeSync(process.stdout.fd, `\x1b]7501;${body}\x1b\\`);
      lastReport = body;
    } catch {
      // A closed terminal must not interrupt the agent. The next event can retry.
      return;
    }
    pi.events.emit("rex:status", { state });
  }

  pi.registerCommand("rex-status", {
    description: "Check and resend this Pi terminal's Rex status",
    handler: async (_args, ctx) => {
      const diagnostics = {
        enabled,
        mode: ctx.mode,
        tty: !!process.stdout.isTTY,
        rexSession: process.env.REX_SESSION ?? null,
        rexBlock: process.env.REX_BLOCK ?? null,
        running,
        prompts,
        lastReport,
      };
      ctx.ui.notify(JSON.stringify(diagnostics, null, 2), "info");
      lastReport = "";
      report(prompts ? "blocked" : running ? "working" : settled, prompts ? "question" : undefined);
    },
  });

  pi.on("session_start", (_event, ctx) => {
    enabled = ctx.mode === "tui" && !!process.stdout.isTTY
      && !!process.env.REX_SESSION && !!process.env.REX_BLOCK;
    running = false;
    failed = false;
    prompts = 0;
    settled = "idle";
    lastReport = "";
    if (enabled) {
      guardPromptMarkers();
      unsubscribeInput = ctx.ui.onTerminalInput((data) => {
        // Focus-in is sent for tab clicks and keyboard tab selection.
        // Do not acknowledge work or dialogs that still need attention.
        if (data === "\x1b[I" && !running && !prompts && settled === "done") {
          settled = "idle";
          report("idle");
        }
        return undefined;
      });
      setFocusReporting(true);
    }
    report("idle");
  });

  pi.on("agent_start", () => {
    running = true;
    failed = false;
    if (!prompts) report("working");
  });

  pi.on("agent_end", (event) => {
    // A retry can replace an error. Only inspect the last run's final message.
    const message = event.messages.findLast((message) => message.role === "assistant");
    failed = message?.role === "assistant" && message.stopReason === "error";
  });

  pi.on("ui_prompt_start", (event) => {
    prompts += 1;
    report("blocked", event.kind === "confirm" ? "permission" : "question");
  });

  pi.on("ui_prompt_end", () => {
    prompts = Math.max(0, prompts - 1);
    if (!prompts) report(running ? "working" : settled);
  });

  pi.on("agent_settled", (event) => {
    running = false;
    settled = event.aborted ? "idle" : failed ? "error" : "done";
    if (!prompts) report(settled);
  });

  pi.on("session_shutdown", () => {
    unsubscribeInput?.();
    unsubscribeInput = undefined;
    if (enabled) setFocusReporting(false);
    report("clear");
    enabled = false;
    if (process.stdout.write === wrappedWrite && originalWrite) {
      process.stdout.write = originalWrite;
    }
    wrappedWrite = undefined;
    originalWrite = undefined;
  });
}
