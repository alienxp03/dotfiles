import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
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

async function harness(t, { idle = true, mode = "tui", status = "running", registered = true } = {}) {
  const handlers = new Map();
  const events = new Map();
  const calls = [];
  const statusCalls = [];
  let tick;
  let record = { surfaceId: "surface-test", workspaceId: "workspace-test", runtimeStatus: status, activePromptTurnId: "turn-test" };
  const save = () => writeFileSync(`${directory}/pi-hook-sessions.json`, JSON.stringify({ sessions: registered ? { "session-test": record } : {} }));
  save();
  t.mock.method(globalThis, "setInterval", (fn) => { tick = fn; return { unref() {} }; });
  t.mock.method(globalThis, "clearInterval", () => {});
  t.mock.method(childProcess.default, "spawn", (_cmd, args) => {
    const child = new EventEmitter();
    child.stdin = new EventEmitter();
    child.stdin.end = (input) => {
      if (args[0] === "set-status") {
        statusCalls.push(args);
      } else {
        const payload = JSON.parse(input);
        calls.push({ action: args[2], args, payload });
        record.runtimeStatus = args[2] === "stop" ? "idle" : args[2] === "notification" ? "needsInput" : "running";
        save();
      }
      queueMicrotask(() => child.emit("close", 0));
    };
    return child;
  });
  syncBuiltinESMExports();
  install({ on: (name, fn) => handlers.set(name, fn), events: { on: (name, fn) => events.set(name, fn) } });
  const ctx = { mode, isIdle: () => idle, cwd: "/test", sessionManager: { getSessionId: () => "session-test" } };
  const flush = async () => { for (let i = 0; i < 8; i++) await new Promise(r => setImmediate(r)); };
  handlers.get("session_start")({}, ctx);
  await flush();
  t.after(async () => { await handlers.get("session_shutdown")(); t.mock.restoreAll(); syncBuiltinESMExports(); });
  return { calls, statusCalls, handlers, events, ctx, flush, tick: () => tick?.(), setIdle: (v) => { idle = v; }, setRegistered: () => { registered = true; save(); }, record };
}

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
  h.setIdle(true); h.handlers.get("agent_settled")(); await h.flush();
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
