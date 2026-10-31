import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import extension from "./index.ts";
import { isAttendingRex } from "./attention.ts";

const flush = () => new Promise<void>(resolve => setImmediate(resolve));

function harness(t) {
  const dir = mkdtempSync(join(tmpdir(), "pi-ntfy-test-"));
  writeFileSync(join(dir, "ntfy.json"), JSON.stringify({ url: "https://example.invalid/private-topic" }));
  const originalDir = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = dir;
  t.after(() => {
    if (originalDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = originalDir;
    rmSync(dir, { recursive: true, force: true });
  });
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const handlers = new Map<string, Function>();
  const bus = new Map<string, Function>();
  const sent: string[] = [];
  const attention = { bundleId: "com.apple.finder", idleSeconds: 0, locked: false };
  t.mock.method(globalThis, "fetch", async (_url, init) => {
    sent.push(String(init.body));
    return new Response("ok");
  });
  extension({
    on: (name, handler) => handlers.set(name, handler),
    events: { on: (name, handler) => bus.set(name, handler) },
    exec: async (command) => ({ code: 0, stdout: command.endsWith("ioreg")
      ? `"IOConsoleLocked" = ${attention.locked ? "Yes" : "No"}`
      : JSON.stringify(attention), stderr: "" }),
  } as any);
  const emit = async (name: string, event: unknown = {}) => {
    await handlers.get(name)?.(event, {});
    await flush();
  };
  const tick = async (ms: number) => { t.mock.timers.tick(ms); await flush(); };
  const text = (value: string) => emit("message_end", {
    message: { role: "assistant", content: [{ type: "text", text: value }] },
  });
  return { sent, attention, emit, tick, text, bus };
}

test("attention probe suppresses only active, unlocked Rex on macOS", async () => {
  let state = { bundleId: "com.superlogical.rex", idleSeconds: 1 };
  let consoleState = '"IOConsoleLocked" = No';
  let code = 0;
  const exec = async (command) => ({ code, stdout: command.endsWith("ioreg") ? consoleState : JSON.stringify(state), stderr: "" });
  assert.equal(await isAttendingRex(exec as any, "darwin"), true);
  state.idleSeconds = 60;
  assert.equal(await isAttendingRex(exec as any, "darwin"), false);
  state.idleSeconds = 1;
  state.bundleId = "com.apple.finder";
  assert.equal(await isAttendingRex(exec as any, "darwin"), false);
  state.bundleId = "com.superlogical.rex";
  consoleState = '"IOConsoleLocked" = Yes';
  assert.equal(await isAttendingRex(exec as any, "darwin"), false);
  consoleState = "unknown";
  assert.equal(await isAttendingRex(exec as any, "darwin"), false);
  code = 1;
  assert.equal(await isAttendingRex(exec as any, "darwin"), false);
  assert.equal(await isAttendingRex(exec as any, "linux"), false);
  assert.equal(await isAttendingRex((async () => { throw Error(); }) as any, "darwin"), false);
  assert.equal(await isAttendingRex((async () => ({ code: 0, stdout: "invalid JSON" })) as any, "darwin"), false);
});

test("Done waits ten seconds and duplicate settlement sends once", async t => {
  const h = harness(t);
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.text("Finished.");
  await h.emit("agent_settled", { aborted: false });
  await h.emit("agent_settled", { aborted: false });
  await h.tick(9999);
  assert.deepEqual(h.sent, []);
  await h.tick(1);
  assert.deepEqual(h.sent, ["Done"]);
});

test("returning to active Rex suppresses the delayed Done", { skip: process.platform !== "darwin" }, async t => {
  const h = harness(t);
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.emit("agent_settled", { aborted: false });
  h.attention.bundleId = "com.superlogical.rex";
  await h.tick(10_000);
  assert.deepEqual(h.sent, []);
});

test("active Rex suppresses questions and blockers; idle or locked Rex does not", { skip: process.platform !== "darwin" }, async t => {
  const h = harness(t);
  h.attention.bundleId = "com.superlogical.rex";
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.emit("ui_prompt_start");
  await h.emit("agent_before_settle", { outcome: "error" });
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.sent, []);
  h.attention.idleSeconds = 60;
  await h.emit("before_agent_start");
  await h.text("Which branch?");
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.sent, ["Input needed"]);
  h.attention.idleSeconds = 0;
  h.attention.locked = true;
  await h.emit("before_agent_start");
  await h.text("Blocked: credentials required.");
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.sent, ["Input needed", "Blocked"]);
});

test("question events deduplicate; resolved questions may notify again", async t => {
  const h = harness(t);
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.emit("ui_prompt_start");
  h.bus.get("rpiv:ask-user:blocked")?.({ active: true, toolCallId: "q1" });
  await h.emit("ui_prompt_start");
  await h.emit("ui_prompt_end");
  await h.text("Which option?");
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.sent, ["Input needed"]);
  h.bus.get("rpiv:ask-user:blocked")?.({ active: false, toolCallId: "q1" });
  await h.emit("ui_prompt_start");
  assert.deepEqual(h.sent, ["Input needed", "Input needed"]);
});

test("new runs and shutdown cancel pending Done", async t => {
  const h = harness(t);
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.emit("agent_settled", { aborted: false });
  await h.emit("before_agent_start");
  await h.tick(10_000);
  assert.deepEqual(h.sent, []);
  await h.emit("agent_settled", { aborted: false });
  await h.emit("session_shutdown");
  await h.tick(10_000);
  assert.deepEqual(h.sent, []);
});

test("cancellation is silent; recovery retains the current run", async t => {
  const h = harness(t);
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.emit("agent_settled", { aborted: true });
  await h.tick(10_000);
  assert.deepEqual(h.sent, []);
  await h.emit("before_agent_start");
  await h.emit("agent_before_settle", { outcome: "error" });
  await h.emit("before_agent_start");
  await h.emit("agent_before_settle", { outcome: "completed" });
  await h.emit("agent_settled", { aborted: false });
  await h.tick(10_000);
  assert.deepEqual(h.sent, ["Done"]);
});
