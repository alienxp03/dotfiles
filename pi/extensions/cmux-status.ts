// Complements cmux's generated cmux-session.ts; do not edit the generated file.
// cmux 0.65.2 counts a fresh, idle Pi process as a running sibling session.
// Reconcile only this TUI session, and bridge the questionnaire's custom UI.
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { CmuxSidebarState, sidebarStatuses, type SidebarPhase } from "./cmux-status/sidebar-state.ts";

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
  let completionPending = false;
  let runningSubagents = 0;
  let runStarted = false;
  let runFailed = false;
  let completedResponse = false;
  let focusWatcher: ReturnType<typeof spawn> | undefined;
  let focusSequence: number | undefined;
  let focusBootId: string | undefined;
  let sidebar: CmuxSidebarState | undefined;

  const cmuxExecutable = () => process.env.CMUX_PI_CMUX_BIN || process.env.CMUX_BUNDLED_CLI_PATH || "cmux";

  function watchFocus() {
    if (!context || focusWatcher) return;
    const epoch = generation;
    const args = [
      "events", "--name", "workspace.selected", "--name", "surface.focused",
      "--name", "pane.focused", "--timeout", "0.25", "--no-heartbeat",
    ];
    if (focusSequence !== undefined) args.push("--after", String(focusSequence));
    // Long-lived subscriptions can exhaust cmux's control-socket workers when
    // many panes are open. Brief polls replay missed focus events by sequence.
    const child = spawn(cmuxExecutable(), args, { timeout: 1500, stdio: ["ignore", "pipe", "ignore"] });
    focusWatcher = child;
    const lines = createInterface({ input: child.stdout! });
    lines.on("line", (line) => {
      if (epoch !== generation) return;
      try {
        const event = JSON.parse(line);
        if (event.type === "ack") {
          const latest = event.resume?.latest_seq;
          if (Number.isSafeInteger(latest) && (focusSequence === undefined
            || focusBootId !== event.boot_id || event.replay_count === 0)) focusSequence = latest;
          focusBootId = event.boot_id;
          return;
        }
        if (event.type !== "event" || !Number.isSafeInteger(event.seq)) return;
        focusSequence = Math.max(focusSequence ?? 0, event.seq);
        if (completedAt === undefined) return;
        const occurredAt = Date.parse(event.occurred_at);
        if (event.type !== "event" || !Number.isFinite(occurredAt) || occurredAt < completedAt
          || event.workspace_id !== process.env.CMUX_WORKSPACE_ID) return;
        const selectedWorkspace = event.name === "workspace.selected";
        const focusedPane = ["surface.focused", "pane.focused"].includes(event.name)
          && event.surface_id === process.env.CMUX_SURFACE_ID;
        if (!selectedWorkspace && !focusedPane) return;
        completedAt = undefined;
        completionPending = false;
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

  async function writeStatus(phase: SidebarPhase) {
    const status = sidebarStatuses[phase];
    await run([
      "set-status", "pi", status.label,
      "--icon", status.icon, "--color", status.color, "--priority", status.priority,
      "--workspace", process.env.CMUX_WORKSPACE_ID!,
    ]);
  }

  async function setStatus(phase: SidebarPhase) {
    const projection = sidebar;
    if (!projection) return;
    const aggregate = await projection.publish(phase);
    // The shared row belongs to the workspace, not whichever pane wrote last.
    if (sidebar === projection) await writeStatus(aggregate);
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

  async function panePhase(ctx: ExtensionContext, record: HookRecord): Promise<SidebarPhase> {
    if (blocked.size > 0) {
      completedAt = undefined;
      completionPending = false;
      if (record.runtimeStatus !== "needsInput") {
        await send(ctx, "notification", record, {
          hook_event_name: "questionAsked", event: "questionAsked", message: "needs_input",
          notification: { type: "question" },
        });
      }
      return "waiting";
    }
    if (ctx.isIdle() && runningSubagents === 0 && record.runtimeStatus === "running") {
      // No toast for a fresh pane or a missed idle transition. Match its turn.
      await send(ctx, "stop", record, { cmux_notification_routed: true });
    } else if (resumePending && record.runtimeStatus === "needsInput") {
      await send(ctx, "approval-response", record, { cmux_pi_idle_dialog: ctx.isIdle() });
      resumePending = false;
    } else if (record.runtimeStatus === "needsInput" && ctx.isIdle() && completedResponse
      && record.turnSettled === true && !record.activePromptTurnId
      && record.hookEventName?.toLowerCase() === "stop") {
      // Completion prose can be classified as approval. Repair only a settled Stop.
      await send(ctx, "approval-response", record, { cmux_pi_idle_dialog: true });
    } else if (record.runtimeStatus === "needsInput") {
      // A completion Notification can arrive before its Stop. Keep pending Done
      // until that boundary lets us verify a misclassification; preserve real waits.
      if (!completedResponse || record.hookEventName?.toLowerCase() !== "notification") {
        completedAt = undefined;
        completionPending = false;
      }
      return "waiting";
    }
    resumePending = false;
    if (ctx.isIdle() && record.runtimeStatus === "error") return "error";
    if (!ctx.isIdle() || runningSubagents > 0) return "running";
    if (completionPending) {
      completedAt = Date.now();
      completionPending = false;
    }
    return completedAt === undefined ? "idle" : "done";
  }

  function reconcile(resume = false) {
    resumePending ||= resume;
    const ctx = context;
    const epoch = generation;
    if (!ctx || pending) return queue;
    pending = true;
    queue = queue.then(async () => {
      if (epoch !== generation || !enabled()) return;
      watchFocus();
      const record = await recordFor(ctx);
      if (!record || epoch !== generation) return;
      const phase = await panePhase(ctx, record);
      if (epoch !== generation) return;
      // Publish working parents too: a sibling's completion or a late native
      // hook must never erase a parent that is still processing its turn.
      const working = !ctx.isIdle() || runningSubagents > 0;
      await setStatus(working && (phase === "idle" || phase === "done") ? "running" : phase);
    }).catch(() => {
      // Socket failures must not interrupt Pi; the timer retries reconciliation.
    }).finally(() => { pending = false; });
    return queue;
  }

  pi.on("session_start", (_event, ctx) => {
    if (timer) clearInterval(timer);
    generation += 1;
    stopFocusWatcher();
    focusSequence = undefined;
    focusBootId = undefined;
    completedAt = undefined;
    completionPending = false;
    runningSubagents = 0;
    runStarted = false;
    runFailed = false;
    completedResponse = false;
    blocked.clear();
    resumePending = false;
    context = ctx.mode === "tui" && enabled() ? ctx : undefined;
    if (!context) return;
    sidebar = new CmuxSidebarState({
      stateDirectory: process.env.CMUX_AGENT_HOOK_STATE_DIR || join(homedir(), ".cmuxterm"),
      workspaceId: process.env.CMUX_WORKSPACE_ID!, surfaceId: process.env.CMUX_SURFACE_ID!,
      sessionId: ctx.sessionManager.getSessionId(), pid: process.pid,
    });
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

  pi.events.on("kesh:subagents", (data: unknown) => {
    if (!context || !data || typeof data !== "object") return;
    const running = (data as { running?: unknown }).running;
    if (typeof running !== "number" || !Number.isInteger(running) || running < 0) return;
    runningSubagents = running;
    if (running > 0 && completedAt !== undefined) {
      completionPending = true;
      completedAt = undefined;
    }
    reconcile();
  });

  pi.on("agent_start", () => {
    if (!context) return;
    completedAt = undefined;
    completionPending = false;
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
      completionPending = true;
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
    const projection = sidebar;
    sidebar = undefined;
    if (projection) {
      const remaining = await projection.remove();
      if (remaining) await writeStatus(remaining);
    }
  });
}
