// Complements cmux's generated cmux-session.ts; do not edit the generated file.
// cmux 0.65.2 counts a fresh, idle Pi process as a running sibling session.
// Reconcile only this TUI session, and bridge the questionnaire's custom UI.
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type HookRecord = {
  surfaceId?: string;
  workspaceId?: string;
  runtimeStatus?: string;
  activePromptTurnId?: string;
};

export default function (pi: ExtensionAPI) {
  let context: ExtensionContext | undefined;
  let timer: ReturnType<typeof setInterval> | undefined;
  let generation = 0;
  let queue = Promise.resolve();
  const blocked = new Set<string>();

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

  async function inputColor() {
    await run([
      "set-status", "pi", "Pi needs input",
      "--icon", "bell.fill", "--color", "#FF9F0A", "--priority", "100",
      "--workspace", process.env.CMUX_WORKSPACE_ID!,
      "--panel", process.env.CMUX_SURFACE_ID!,
    ]);
  }

  async function run(args: string[], input?: string) {
    await new Promise<void>((resolve, reject) => {
      const child = spawn(
        process.env.CMUX_PI_CMUX_BIN || process.env.CMUX_BUNDLED_CLI_PATH || "cmux",
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
      const record = await recordFor(ctx);
      if (!record || epoch !== generation) return;
      if (blocked.size > 0) {
        if (record.runtimeStatus !== "needsInput") {
          await send(ctx, "notification", record, {
            hook_event_name: "questionAsked",
            event: "questionAsked",
            message: "needs_input",
            notification: { type: "question" },
          });
        }
        await inputColor();
      } else if (ctx.isIdle() && record.runtimeStatus === "running") {
        // No completion toast for a fresh pane or a missed idle transition.
        // Match the stored turn so a delayed repair cannot finish a newer prompt.
        await send(ctx, "stop", record, { cmux_notification_routed: true });
      } else if (resumePending && record.runtimeStatus === "needsInput") {
        await send(ctx, "approval-response", record, { cmux_pi_idle_dialog: ctx.isIdle() });
        resumePending = false;
      } else if (record.runtimeStatus === "needsInput") {
        // Also color standard dialogs and final questions reported by the native hook.
        // Reapply on ticks because native hooks use blue for both working and input.
        await inputColor();
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
    blocked.clear();
    resumePending = false;
    context = ctx.mode === "tui" && enabled() ? ctx : undefined;
    if (!context) return;
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

  pi.on("agent_settled", () => reconcile());
  pi.on("session_shutdown", async () => {
    generation += 1;
    if (timer) clearInterval(timer);
    timer = undefined;
    context = undefined;
    blocked.clear();
    await queue;
  });
}
