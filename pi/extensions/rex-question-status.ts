import { writeSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pi 1.4's custom UI does not set native Blocked status. Bridge the question
// extension's explicit wait events into Pi's existing root record, not a second id.
const waiting = `\x1b]7501;state=blocked:kind=question:app=pi:msg=${Buffer.from("Needs input").toString("base64")}\x1b\\`;

export default function (pi: ExtensionAPI) {
  const questions = new Set<string>();
  let enabled = false;
  let nativeStatus = "";
  let restore: (() => void) | undefined;

  function writeStatus(status: string) {
    try {
      writeSync(process.stdout.fd, status);
    } catch {
      // Terminal output failure must not interrupt the questionnaire.
    }
  }

  function stop() {
    if (enabled && questions.size) writeStatus(nativeStatus);
    enabled = false;
    questions.clear();
    restore?.();
    restore = undefined;
  }

  pi.on("session_start", (_event, ctx) => {
    stop();
    enabled = ctx.mode === "tui" && !!process.stdout.isTTY
      && !!process.env.REX_SESSION && !!process.env.REX_BLOCK;
    if (!enabled) return;
    // Startup/reload may precede the next native report.
    nativeStatus = `\x1b]7501;state=${ctx.isIdle() ? "idle" : "working"}:app=pi\x1b\\`;
    const original = process.stdout.write;
    let active = true;
    const wrapped = ((chunk: string | Uint8Array, ...args: any[]) => {
      if (active && typeof chunk === "string") {
        chunk = chunk.replace(/\x1b\]7501;([^\x07\x1b]*)(?:\x07|\x1b\\)/g, (report, body: string) => {
          const pairs = body.split(":");
          if (!pairs.includes("app=pi") || pairs.some((pair) => pair.startsWith("id="))) return report;
          nativeStatus = report;
          // Keep the wait visible if another native lifecycle event occurs.
          // Suppress, rather than repeat Blocked and create fresh notifications.
          return questions.size ? "" : report;
        });
      }
      return original.call(process.stdout, chunk, ...args);
    }) as typeof process.stdout.write;
    process.stdout.write = wrapped;
    restore = () => {
      active = false;
      if (process.stdout.write === wrapped) process.stdout.write = original;
    };
  });

  pi.events.on("rpiv:ask-user:blocked", (data: unknown) => {
    if (!enabled || !data || typeof data !== "object") return;
    const event = data as { active?: unknown; toolCallId?: unknown };
    if (typeof event.active !== "boolean" || typeof event.toolCallId !== "string" || !event.toolCallId) return;
    const wasWaiting = questions.size > 0;
    if (event.active) questions.add(event.toolCallId);
    else questions.delete(event.toolCallId);
    const isWaiting = questions.size > 0;
    if (wasWaiting !== isWaiting) writeStatus(isWaiting ? waiting : nativeStatus);
  });

  pi.on("session_shutdown", stop);
}
