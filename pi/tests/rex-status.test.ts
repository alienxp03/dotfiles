import assert from "node:assert/strict";
import { test } from "node:test";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import install from "../extensions/rex-status.ts";

function harness(t, { mode = "tui", rex = true, tty = true } = {}) {
  const handlers = new Map();
  const reports = [];
  const statuses = [];
  const controls = [];
  let inputHandler;
  let unsubscribed = false;
  const previous = { session: process.env.REX_SESSION, block: process.env.REX_BLOCK };
  const descriptor = Object.getOwnPropertyDescriptor(process.stdout, "isTTY");
  process.env.REX_SESSION = rex ? "session:test" : "";
  process.env.REX_BLOCK = rex ? "block:test" : "";
  Object.defineProperty(process.stdout, "isTTY", { configurable: true, value: tty });
  t.mock.method(fs, "writeSync", (fd, chunk) => {
    assert.equal(fd, process.stdout.fd);
    if (chunk.startsWith("\x1b]7501;")) reports.push(chunk);
    else controls.push(chunk);
    return Buffer.byteLength(chunk);
  });
  syncBuiltinESMExports();
  install({
    on: (name, handler) => handlers.set(name, handler),
    registerCommand: (name, command) => handlers.set(name, command.handler),
    events: { emit: (name, event) => statuses.push({ name, ...event }) },
  });
  const notifications = [];
  const emit = (name, event = {}) => handlers.get(name)(event, {
    mode,
    ui: {
      notify: (message) => notifications.push(JSON.parse(message)),
      onTerminalInput: (handler) => {
        inputHandler = handler;
        return () => { unsubscribed = true; };
      },
    },
  });
  emit("session_start");
  t.after(() => {
    emit("session_shutdown");
    t.mock.restoreAll();
    syncBuiltinESMExports();
    if (descriptor) Object.defineProperty(process.stdout, "isTTY", descriptor);
    else delete process.stdout.isTTY;
    for (const [key, value] of [["REX_SESSION", previous.session], ["REX_BLOCK", previous.block]]) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  const states = () => reports.map((report) => report.match(/state=(\w+)/)[1]);
  const end = (stopReason) => emit("agent_end", { messages: [{ role: "assistant", stopReason }] });
  return {
    emit, reports, states, end, notifications, statuses, controls,
    input: (data) => inputHandler?.(data),
    unsubscribed: () => unsubscribed,
  };
}

test("reports startup, work, final settlement and scoped cleanup", (t) => {
  const h = harness(t);
  h.emit("agent_start");
  h.end("stop");
  assert.deepEqual(h.states(), ["idle", "working"]);
  h.emit("agent_settled", { aborted: false });
  h.emit("session_shutdown");
  assert.deepEqual(h.states(), ["idle", "working", "done", "clear"]);
  assert.deepEqual(h.statuses.map((event) => event.state), h.states());
  assert.ok(h.statuses.every((event) => event.name === "rex:status"));
  assert.ok(h.reports.every((report) => report.includes(":id=pi:app=pi") && report.endsWith("\x1b\\")));
  h.emit("agent_start");
  assert.equal(h.reports.length, 4);
});

test("reports approval and custom dialogs, then resumes work", (t) => {
  const h = harness(t);
  h.emit("agent_start");
  h.emit("ui_prompt_start", { kind: "confirm" });
  assert.ok(h.reports.at(-1).includes(":kind=permission"));
  h.emit("ui_prompt_start", { kind: "custom" });
  assert.ok(h.reports.at(-1).includes(":kind=question"));
  h.emit("ui_prompt_end");
  assert.equal(h.states().at(-1), "blocked");
  h.emit("ui_prompt_end");
  assert.equal(h.states().at(-1), "working");
});

test("keeps an open dialog blocked through settlement", (t) => {
  const h = harness(t);
  h.emit("agent_start");
  h.emit("ui_prompt_start", { kind: "input" });
  h.emit("agent_settled", { aborted: false });
  assert.equal(h.states().at(-1), "blocked");
  h.emit("ui_prompt_end");
  assert.equal(h.states().at(-1), "done");
});

test("reports errors only on settlement, resets after retries, and handles cancellation", (t) => {
  const h = harness(t);
  h.emit("agent_start");
  h.end("error");
  h.emit("agent_settled", { aborted: false });
  assert.equal(h.states().at(-1), "error");
  h.emit("agent_start");
  h.end("error");
  h.emit("agent_start");
  h.end("stop");
  h.emit("agent_settled", { aborted: false });
  assert.equal(h.states().at(-1), "done");
  h.emit("agent_start");
  h.emit("agent_settled", { aborted: true });
  assert.equal(h.states().at(-1), "idle");
});

test("clears completion on focus-in, not focus-out or ordinary typing", (t) => {
  const h = harness(t);
  assert.deepEqual(h.controls, ["\x1b[?1004h"]);
  h.emit("agent_start");
  h.input("\x1b[I");
  assert.equal(h.states().at(-1), "working");
  h.emit("agent_settled", { aborted: false });
  h.input("\x1b[O");
  h.input("x");
  assert.equal(h.states().at(-1), "done");
  assert.equal(h.input("\x1b[I"), undefined);
  assert.equal(h.states().at(-1), "idle");
  h.emit("session_shutdown");
  assert.equal(h.controls.at(-1), "\x1b[?1004l");
  assert.equal(h.unsubscribed(), true);
});

test("focus-in does not clear an open dialog or error", (t) => {
  const h = harness(t);
  h.emit("agent_start");
  h.emit("ui_prompt_start", { kind: "confirm" });
  h.emit("agent_settled", { aborted: false });
  h.input("\x1b[I");
  assert.equal(h.states().at(-1), "blocked");
  h.emit("ui_prompt_end");
  h.emit("agent_start");
  h.end("error");
  h.emit("agent_settled", { aborted: false });
  h.input("\x1b[I");
  assert.equal(h.states().at(-1), "error");
});

test("diagnostic command shows the live gates and resends status", async (t) => {
  const h = harness(t);
  await h.emit("rex-status");
  assert.equal(h.notifications[0].enabled, true);
  assert.equal(h.notifications[0].mode, "tui");
  assert.equal(h.notifications[0].tty, true);
  assert.deepEqual(h.states(), ["idle", "idle"]);
});

test("removes transcript prompt markers only in Rex and restores stdout on shutdown", (t) => {
  const output = [];
  const write = process.stdout.write;
  const capture = ((chunk) => { output.push(chunk); return true; });
  process.stdout.write = capture;
  t.after(() => { process.stdout.write = write; });
  const h = harness(t);
  process.stdout.write("\x1b]133;A\x07Hello\x1b]133;B\x1b\\\x1b]133;C\x07");
  process.stdout.write("\x1b]7501;state=working:app=pi\x1b\\");
  h.emit("session_shutdown");
  assert.equal(process.stdout.write, capture);
  assert.deepEqual(output, ["Hello", "\x1b]7501;state=working:app=pi\x1b\\"]);
});

for (const options of [{ mode: "rpc" }, { mode: "json" }, { mode: "print" }, { rex: false }, { tty: false }]) {
  test(`no output outside an interactive Rex terminal: ${JSON.stringify(options)}`, (t) => {
    const h = harness(t, options);
    h.emit("agent_start");
    h.emit("ui_prompt_start", { kind: "custom" });
    h.emit("ui_prompt_end");
    h.emit("agent_settled", { aborted: false });
    h.emit("session_shutdown");
    assert.deepEqual(h.reports, []);
  });
}
