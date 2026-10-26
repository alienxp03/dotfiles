import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import * as childProcess from "node:child_process";
import { syncBuiltinESMExports } from "node:module";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import install from "../extensions/cmux-status.ts";

const directory = resolve("aux/cmux-debug/state");
mkdirSync(directory, { recursive: true });
process.env.CMUX_AGENT_HOOK_STATE_DIR = directory;
process.env.CMUX_SURFACE_ID = "surface-test";
process.env.CMUX_WORKSPACE_ID = "workspace-test";
delete process.env.CMUX_PI_HOOKS_DISABLED;

async function harness(t, { idle = true, mode = "tui", status = "running", registered = true, branch = [], recordState = {} } = {}) {
  const handlers = new Map();
  const events = new Map();
  const calls = [];
  const statusCalls = [];
  const watchers = [];
  let tick;
  let record = { surfaceId: "surface-test", workspaceId: "workspace-test", runtimeStatus: status, activePromptTurnId: "turn-test", ...recordState };
  const save = () => writeFileSync(`${directory}/pi-hook-sessions.json`, JSON.stringify({ sessions: registered ? { "session-test": record } : {} }));
  save();
  t.mock.method(globalThis, "setInterval", (fn) => { tick = fn; return { unref() {} }; });
  t.mock.method(globalThis, "clearInterval", () => {});
  t.mock.method(childProcess.default, "spawn", (_cmd, args) => {
    const child = new EventEmitter();
    if (args[0] === "events") {
      child.stdout = new PassThrough();
      child.kill = () => { child.stdout.end(); child.emit("close", 0); };
      watchers.push(child);
      return child;
    }
    child.stdin = new EventEmitter();
    child.stdin.end = (input) => {
      if (args[0] === "set-status") {
        statusCalls.push(args);
      } else {
        const payload = JSON.parse(input);
        calls.push({ action: args[2], args, payload });
        record.runtimeStatus = args[2] === "stop" || payload.cmux_pi_idle_dialog === true ? "idle"
          : args[2] === "notification" ? "needsInput" : "running";
        save();
      }
      queueMicrotask(() => child.emit("close", 0));
    };
    return child;
  });
  syncBuiltinESMExports();
  install({ on: (name, fn) => handlers.set(name, fn), events: { on: (name, fn) => events.set(name, fn) } });
  const ctx = { mode, isIdle: () => idle, cwd: "/test", sessionManager: { getSessionId: () => "session-test", getBranch: () => branch } };
  const flush = async () => { for (let i = 0; i < 8; i++) await new Promise(r => setImmediate(r)); };
  handlers.get("session_start")({}, ctx);
  await flush();
  t.after(async () => { await handlers.get("session_shutdown")(); t.mock.restoreAll(); syncBuiltinESMExports(); });
  const focus = (event = {}) => watchers.at(-1).stdout.write(`${JSON.stringify({
    type: "event", name: "workspace.selected", workspace_id: "workspace-test",
    occurred_at: new Date().toISOString(), ...event,
  })}\n`);
  const complete = async (event = {}, text = "Done") => {
    handlers.get("agent_start")({}, ctx);
    handlers.get("agent_end")({ messages: [{ role: "assistant", stopReason: "stop", content: [{ type: "text", text }] }] }, ctx);
    idle = true;
    handlers.get("agent_settled")({ aborted: false, ...event }, ctx);
    await flush();
    tick(); await flush();
  };
  return { calls, statusCalls, watchers, focus, complete, handlers, events, ctx, flush, tick: () => tick?.(), setIdle: (v) => { idle = v; }, setRegistered: () => { registered = true; save(); }, record };
}

test("Done stays green until the workspace is selected", async t => {
  const h = await harness(t, { idle: false });
  await h.complete();
  assert.deepEqual(h.statusCalls.at(-1).slice(0, 3), ["set-status", "pi", "Done"]);
  assert.ok(h.statusCalls.at(-1).includes("#30D158"));
  h.tick(); await h.flush();
  assert.equal(h.statusCalls.at(-1)[2], "Done");
  h.focus(); await h.flush();
  assert.equal(h.statusCalls.at(-1)[2], "Idle");
  assert.ok(h.statusCalls.at(-1).includes("#8E8E93"));
  const count = h.statusCalls.length;
  h.tick(); await h.flush();
  assert.equal(h.statusCalls.length, count);
});
test("only this pane or workspace acknowledges completion", async t => {
  const h = await harness(t, { idle: false });
  await h.complete();
  const count = h.statusCalls.length;
  h.focus({ workspace_id: "other-workspace" });
  h.focus({ name: "surface.focused", surface_id: "other-surface" });
  h.focus({ name: "surface.selected", surface_id: "surface-test" });
  await h.flush();
  assert.equal(h.statusCalls.length, count);
  h.focus({ name: "pane.focused", surface_id: "surface-test" }); await h.flush();
  assert.equal(h.statusCalls.at(-1)[2], "Idle");
});
test("replayed focus and malformed events cannot clear Done", async t => {
  const h = await harness(t, { idle: false });
  await h.complete();
  const count = h.statusCalls.length;
  h.focus({ occurred_at: "2000-01-01T00:00:00Z" });
  h.focus({ occurred_at: "invalid" });
  h.focus({ type: "ack" });
  h.watchers.at(-1).stdout.write("not-json\n");
  await h.flush();
  assert.equal(h.statusCalls.length, count);
});
test("a new run clears pending Done", async t => {
  const h = await harness(t, { idle: false });
  await h.complete();
  h.setIdle(false);
  h.handlers.get("agent_start")({}, h.ctx);
  const count = h.statusCalls.length;
  h.focus(); h.tick(); await h.flush();
  assert.equal(h.statusCalls.length, count);
});
test("aborted and failed runs do not show Done", async t => {
  const h = await harness(t, { idle: false });
  await h.complete({ aborted: true });
  assert.equal(h.statusCalls.length, 0);
  h.handlers.get("agent_start")({}, h.ctx);
  h.handlers.get("agent_end")({ messages: [{ role: "assistant", stopReason: "error" }] }, h.ctx);
  h.handlers.get("agent_settled")({ aborted: false }, h.ctx);
  await h.flush(); h.tick(); await h.flush();
  assert.equal(h.statusCalls.length, 0);
});
test("a final question takes precedence over Done", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: true, hookEventName: "Stop", activePromptTurnId: undefined } });
  await h.complete({}, "Shall I continue?");
  assert.equal(h.statusCalls.at(-1)[2], "Pi needs input");
  assert.ok(!h.statusCalls.some(args => args[2] === "Done"));
});
test("repairs a completion misclassified as an approval request", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: true, hookEventName: "Stop", activePromptTurnId: undefined } });
  await h.complete({}, "Also completed the approved CodeScene refactor.");
  assert.equal(h.calls[0].action, "approval-response");
  assert.equal(h.calls[0].payload.cmux_pi_idle_dialog, true);
  assert.equal(h.record.runtimeStatus, "idle");
  assert.equal(h.statusCalls.at(-1)[2], "Done");
});
test("retains Done when the misclassified Notification arrives before Stop", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: false, hookEventName: "Notification", activePromptTurnId: undefined } });
  await h.complete({}, "Approved refactor completed.");
  assert.equal(h.calls.length, 0);
  Object.assign(h.record, { turnSettled: true, hookEventName: "Stop" });
  h.setRegistered(); h.tick(); await h.flush();
  assert.equal(h.calls[0].action, "approval-response");
  assert.equal(h.statusCalls.at(-1)[2], "Done");
});
test("reload repairs stale completed input state without announcing a new completion", async t => {
  const h = await harness(t, { status: "needsInput",
    recordState: { turnSettled: true, hookEventName: "Stop", activePromptTurnId: undefined },
    branch: [{ type: "message", message: { role: "assistant", stopReason: "stop", content: "Approved changes completed." } }] });
  assert.equal(h.calls[0].action, "approval-response");
  assert.equal(h.record.runtimeStatus, "idle");
  assert.equal(h.statusCalls.at(-1)[2], "Idle");
});
test("a live native dialog is not mistaken for a completed approval", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: true, hookEventName: "questionAsked", activePromptTurnId: undefined } });
  await h.complete();
  assert.equal(h.calls.length, 0);
  assert.equal(h.statusCalls.at(-1)[2], "Pi needs input");
});
test("an unsettled turn is not repaired even when Pi reports idle", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: false, hookEventName: "Stop", activePromptTurnId: undefined } });
  await h.complete();
  assert.equal(h.calls.length, 0);
  assert.equal(h.statusCalls.at(-1)[2], "Pi needs input");
});
test("an active prompt is not repaired", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: true, hookEventName: "Stop" } });
  await h.complete();
  assert.equal(h.calls.length, 0);
});
test("an open custom questionnaire is not repaired", async t => {
  const h = await harness(t, { status: "needsInput", idle: false,
    recordState: { turnSettled: true, hookEventName: "Stop", activePromptTurnId: undefined } });
  h.events.get("rpiv:ask-user:blocked")({ active: true, toolCallId: "open-question" });
  await h.flush();
  await h.complete();
  assert.equal(h.calls.length, 0);
  assert.equal(h.statusCalls.at(-1)[2], "Pi needs input");
});
test("reload preserves a genuine final question", async t => {
  const h = await harness(t, { status: "needsInput",
    recordState: { turnSettled: true, hookEventName: "Stop", activePromptTurnId: undefined },
    branch: [{ type: "message", message: { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "Proceed？" }] } }] });
  assert.equal(h.calls.length, 0);
  assert.equal(h.statusCalls.at(-1)[2], "Pi needs input");
});
test("shutdown closes the focus subscription", async t => {
  const h = await harness(t);
  await h.handlers.get("session_shutdown")();
  assert.equal(h.watchers[0].stdout.writableEnded, true);
});

test("fresh idle pane settles its native running record silently", async t => {
  const h = await harness(t);
  assert.equal(h.calls.length, 1);
  assert.equal(h.calls[0].action, "stop");
  assert.equal(h.calls[0].payload.turn_id, "turn-test");
  assert.equal(h.calls[0].payload.cmux_notification_routed, true);
  h.tick(); await h.flush();
  assert.equal(h.calls.length, 1);
});
test("waits for detached native registration", async t => {
  const h = await harness(t, { registered: false });
  assert.equal(h.calls.length, 0);
  h.setRegistered(); h.tick(); await h.flush();
  assert.equal(h.calls[0].action, "stop");
});
test("does not stop a working agent", async t => {
  const h = await harness(t, { idle: false });
  h.tick(); await h.flush();
  assert.equal(h.calls.length, 0);
});
test("settled agent repairs a missed idle transition", async t => {
  const h = await harness(t, { idle: false });
  h.setIdle(true); h.handlers.get("agent_settled")({ aborted: false }, h.ctx); await h.flush();
  assert.equal(h.calls[0].action, "stop");
});
test("custom questionnaire waits for all answers before resuming", async t => {
  const h = await harness(t, { idle: false });
  const blocked = h.events.get("rpiv:ask-user:blocked");
  blocked({ active: true, toolCallId: "a" }); await h.flush();
  assert.equal(h.calls[0].action, "notification");
  assert.equal(h.calls[0].payload.hook_event_name, "questionAsked");
  assert.ok(h.statusCalls[0].includes("#FF9F0A"));
  assert.deepEqual(h.statusCalls[0].slice(-4), ["--workspace", "workspace-test", "--panel", "surface-test"]);
  blocked({ active: true, toolCallId: "b" }); await h.flush();
  blocked({ active: false, toolCallId: "a" }); await h.flush();
  assert.equal(h.calls.length, 1);
  blocked({ active: false, toolCallId: "b" }); await h.flush();
  assert.equal(h.calls[1].action, "approval-response");
  const count = h.statusCalls.length;
  h.tick(); await h.flush();
  assert.equal(h.statusCalls.length, count);
});
test("idle questionnaire returns to idle after the answer", async t => {
  const h = await harness(t);
  const blocked = h.events.get("rpiv:ask-user:blocked");
  blocked({ active: true, toolCallId: "a" }); await h.flush();
  blocked({ active: false, toolCallId: "a" }); await h.flush();
  assert.equal(h.calls.at(-1).action, "approval-response");
  assert.equal(h.calls.at(-1).payload.cmux_pi_idle_dialog, true);
});
test("colors a native final-question state without changing its lifecycle", async t => {
  const h = await harness(t, { status: "needsInput" });
  assert.equal(h.calls.length, 0);
  assert.ok(h.statusCalls[0].includes("#FF9F0A"));
  h.tick(); await h.flush();
  assert.equal(h.statusCalls.length, 2);
});
test("headless children cannot change parent pane state", async t => {
  const h = await harness(t, { mode: "rpc" });
  h.tick(); await h.flush();
  assert.equal(h.calls.length, 0);
});
test("does not act on records for a different pane", async t => {
  const h = await harness(t, { registered: false });
  h.record.surfaceId = "different-pane"; h.setRegistered(); h.tick(); await h.flush();
  assert.equal(h.calls.length, 0);
});
