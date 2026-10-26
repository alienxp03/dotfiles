// Complements cmux's generated cmux-session.ts; do not edit the generated file.
// cmux 0.65.2 counts a fresh, idle Pi process as a running sibling session.
// Reconcile only this TUI session, and bridge the questionnaire's custom UI.
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type HookRecord = {
  surfaceId?: string;
  workspaceId?: string;
  runtimeStatus?: string;
  activePromptTurnId?: string;
  turnSettled?: boolean;
  hookEventName?: string;
};

function isCompletedResponse(value: unknown): boolean {
  if (!value || typeof value !== "object") return false;
  const message = value as { role?: unknown; stopReason?: unknown; content?: unknown };
  if (message.role !== "assistant" || !["stop", "length"].includes(String(message.stopReason))) return false;
  const text = typeof message.content === "string" ? message.content
    : Array.isArray(message.content) ? message.content
      .filter((block) => block?.type === "text" && typeof block.text === "string")
      .map((block) => block.text).join("\n") : "";
  // Match the generated hook's final-question rule, not cmux's keyword classifier.
  return !/[?？]\s*$/.test(text.trim());
}

export default function (pi: ExtensionAPI) {
  let context: ExtensionContext | undefined;
  let timer: ReturnType<typeof setInterval> | undefined;
  let generation = 0;
  let queue = Promise.resolve();
  const blocked = new Set<string>();
  let completedAt: number | undefined;
  let completionAcknowledged = false;
  let runStarted = false;
  let runFailed = false;
  let completedResponse = false;
  let focusWatcher: ReturnType<typeof spawn> | undefined;

  const cmuxExecutable = () => process.env.CMUX_PI_CMUX_BIN || process.env.CMUX_BUNDLED_CLI_PATH || "cmux";

  function watchFocus() {
    if (!context || focusWatcher) return;
    const epoch = generation;
    const child = spawn(cmuxExecutable(), [
      "events", "--name", "workspace.selected", "--name", "surface.focused",
      "--name", "pane.focused", "--reconnect", "--no-heartbeat",
    ], { stdio: ["ignore", "pipe", "ignore"] });
    focusWatcher = child;
    const lines = createInterface({ input: child.stdout! });
    lines.on("line", (line) => {
      if (epoch !== generation || completedAt === undefined) return;
      try {
        const event = JSON.parse(line);
        const occurredAt = Date.parse(event.occurred_at);
        if (event.type !== "event" || !Number.isFinite(occurredAt) || occurredAt < completedAt
          || event.workspace_id !== process.env.CMUX_WORKSPACE_ID) return;
        const selectedWorkspace = event.name === "workspace.selected";
        const focusedPane = ["surface.focused", "pane.focused"].includes(event.name)
          && event.surface_id === process.env.CMUX_SURFACE_ID;
        if (!selectedWorkspace && !focusedPane) return;
        completedAt = undefined;
        completionAcknowledged = true;
        reconcile();
      } catch {
        // Ignore malformed stream frames; never treat them as acknowledgment.
      }
    });
    const closed = () => {
      lines.close();
      if (focusWatcher === child) focusWatcher = undefined;
    };
    child.on("error", closed);
    child.on("close", closed);
  }

  function stopFocusWatcher() {
    focusWatcher?.kill();
    focusWatcher = undefined;
  }

  const enabled = () => process.env.CMUX_PI_HOOKS_DISABLED !== "1"
    && !!process.env.CMUX_SURFACE_ID
    && !!process.env.CMUX_WORKSPACE_ID;

  async function recordFor(ctx: ExtensionContext): Promise<HookRecord | undefined> {
    const directory = process.env.CMUX_AGENT_HOOK_STATE_DIR || join(homedir(), ".cmuxterm");
    try {
      const state = JSON.parse(await readFile(join(directory, "pi-hook-sessions.json"), "utf8"));
      const record: HookRecord | undefined = state.sessions?.[ctx.sessionManager.getSessionId()];
      if (record?.surfaceId !== process.env.CMUX_SURFACE_ID
        || record?.workspaceId !== process.env.CMUX_WORKSPACE_ID) return undefined;
      return record;
    } catch {
      // The generated hook may not have registered this session yet. Retry on the next tick.
      return undefined;
    }
  }

  async function send(ctx: ExtensionContext, action: string, record: HookRecord, extra = {}) {
    const args = [
      "hooks", "pi", action,
      "--workspace", process.env.CMUX_WORKSPACE_ID!,
      "--surface", process.env.CMUX_SURFACE_ID!,
    ];
    const input = JSON.stringify({
      session_id: ctx.sessionManager.getSessionId(),
      cwd: ctx.cwd,
      turn_id: record.activePromptTurnId,
      ...extra,
    });
    await run(args, input);
  }

  async function setStatus(label: string, icon: string, color: string, priority = "0") {
    await run([
      "set-status", "pi", label,
      "--icon", icon, "--color", color, "--priority", priority,
      "--workspace", process.env.CMUX_WORKSPACE_ID!,
      "--panel", process.env.CMUX_SURFACE_ID!,
    ]);
  }

  async function run(args: string[], input?: string) {
    await new Promise<void>((resolve, reject) => {
      const child = spawn(
        cmuxExecutable(),
        args,
        { timeout: 5000, stdio: ["pipe", "ignore", "ignore"] },
      );
      child.on("error", reject);
      child.on("close", (code) => code === 0 ? resolve() : reject(new Error("cmux status hook failed")));
      child.stdin.on("error", reject);
      child.stdin.end(input);
    });
  }

  let pending = false;
  let resumePending = false;

  function reconcile(resume = false) {
    resumePending ||= resume;
    const ctx = context;
    const epoch = generation;
    if (!ctx) return;
    // Keep timer ticks bounded: at most one reconciliation can wait behind a command.
    if (pending) return;
    pending = true;
    queue = queue.then(async () => {
      if (epoch !== generation || !enabled()) return;
      watchFocus();
      const record = await recordFor(ctx);
      if (!record || epoch !== generation) return;
      if (blocked.size > 0) {
        completedAt = undefined;
        if (record.runtimeStatus !== "needsInput") {
          await send(ctx, "notification", record, {
            hook_event_name: "questionAsked",
            event: "questionAsked",
            message: "needs_input",
            notification: { type: "question" },
          });
        }
        await setStatus("Pi needs input", "bell.fill", "#FF9F0A", "100");
      } else if (ctx.isIdle() && record.runtimeStatus === "running") {
        // No completion toast for a fresh pane or a missed idle transition.
        // Match the stored turn so a delayed repair cannot finish a newer prompt.
        await send(ctx, "stop", record, { cmux_notification_routed: true });
      } else if (resumePending && record.runtimeStatus === "needsInput") {
        await send(ctx, "approval-response", record, { cmux_pi_idle_dialog: ctx.isIdle() });
        resumePending = false;
      } else if (record.runtimeStatus === "needsInput" && ctx.isIdle() && completedResponse
        && record.turnSettled === true && !record.activePromptTurnId
        && record.hookEventName?.toLowerCase() === "stop") {
        // cmux can classify completion prose (for example, “approved refactor”)
        // as an approval request. Repair only a settled Stop, never a live dialog.
        await send(ctx, "approval-response", record, { cmux_pi_idle_dialog: true });
        if (epoch === generation && ctx.isIdle() && blocked.size === 0) {
          await setStatus(completedAt === undefined ? "Idle" : "Done",
            completedAt === undefined ? "pause.circle.fill" : "checkmark.circle.fill",
            completedAt === undefined ? "#8E8E93" : "#30D158");
        }
      } else if (record.runtimeStatus === "needsInput") {
        // A completion Notification can arrive before its Stop. Retain Done
        // until that boundary lets us verify and repair a misclassification.
        if (!completedResponse || record.hookEventName?.toLowerCase() !== "notification") {
          completedAt = undefined;
        }
        // Also color standard dialogs and final questions reported by the native hook.
        // Reapply on ticks because native hooks use blue for both working and input.
        await setStatus("Pi needs input", "bell.fill", "#FF9F0A", "100");
      } else if (ctx.isIdle() && completedAt !== undefined) {
        await setStatus("Done", "checkmark.circle.fill", "#30D158");
      } else if (ctx.isIdle() && completionAcknowledged) {
        await setStatus("Idle", "pause.circle.fill", "#8E8E93");
        completionAcknowledged = false;
      } else if (record.runtimeStatus === "running" || ctx.isIdle()) {
        resumePending = false;
      }
    }).catch(() => {
      // Socket failures must not interrupt Pi; the timer retries reconciliation.
    }).finally(() => { pending = false; });
  }

  pi.on("session_start", (_event, ctx) => {
    if (timer) clearInterval(timer);
    generation += 1;
    stopFocusWatcher();
    completedAt = undefined;
    completionAcknowledged = false;
    runStarted = false;
    runFailed = false;
    completedResponse = false;
    blocked.clear();
    resumePending = false;
    context = ctx.mode === "tui" && enabled() ? ctx : undefined;
    if (!context) return;
    const lastAssistant = ctx.sessionManager.getBranch().findLast((entry) =>
      entry.type === "message" && entry.message.role === "assistant");
    completedResponse = ctx.isIdle() && lastAssistant?.type === "message"
      && isCompletedResponse(lastAssistant.message);
    watchFocus();
    // Native session registration is detached. Poll instead of racing its startup hook.
    timer = setInterval(() => reconcile(), 2000);
    timer.unref();
    reconcile();
  });

  pi.events.on("rpiv:ask-user:blocked", (data: unknown) => {
    if (!context || !data || typeof data !== "object") return;
    const event = data as { active?: boolean; toolCallId?: string };
    if (typeof event.active !== "boolean" || !event.toolCallId) return;
    if (event.active) blocked.add(event.toolCallId);
    else blocked.delete(event.toolCallId);
    reconcile(!event.active);
  });

  pi.on("agent_start", () => {
    if (!context) return;
    completedAt = undefined;
    completionAcknowledged = false;
    runStarted = true;
    runFailed = false;
    completedResponse = false;
  });
  pi.on("agent_end", (event) => {
    const assistant = event.messages.findLast((message) => message.role === "assistant");
    completedResponse = isCompletedResponse(assistant);
    runFailed = assistant?.role === "assistant"
      && (assistant.stopReason === "error" || assistant.stopReason === "aborted");
  });
  pi.on("agent_settled", (event, ctx) => {
    if (event.aborted) completedResponse = false;
    if (context && ctx.isIdle() && runStarted && completedResponse && !runFailed && !event.aborted) {
      completedAt = Date.now();
      completionAcknowledged = false;
    }
    runStarted = false;
    reconcile();
  });
  pi.on("session_shutdown", async () => {
    generation += 1;
    stopFocusWatcher();
    if (timer) clearInterval(timer);
    timer = undefined;
    context = undefined;
    blocked.clear();
    await queue;
  });
}
