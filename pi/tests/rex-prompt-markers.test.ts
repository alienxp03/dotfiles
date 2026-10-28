import assert from "node:assert/strict";
import { test } from "node:test";
import install from "../extensions/rex-prompt-markers.ts";

function harness(t, { mode = "tui", tty = true, session = "session:test", block = "block:test" } = {}) {
  const handlers = new Map();
  const calls = [];
  const descriptor = Object.getOwnPropertyDescriptor(process.stdout, "isTTY");
  const saved = { REX_SESSION: process.env.REX_SESSION, REX_BLOCK: process.env.REX_BLOCK };
  process.env.REX_SESSION = session;
  process.env.REX_BLOCK = block;
  Object.defineProperty(process.stdout, "isTTY", { configurable: true, value: tty });
  const original = t.mock.method(process.stdout, "write", function (...args) {
    calls.push({ receiver: this, args });
    return false;
  });
  install({ on: (name, handler) => handlers.set(name, handler) });
  const start = () => handlers.get("session_start")({}, { mode });
  const stop = () => handlers.get("session_shutdown")();
  t.after(() => {
    stop();
    t.mock.restoreAll();
    if (descriptor) Object.defineProperty(process.stdout, "isTTY", descriptor);
    else delete process.stdout.isTTY;
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  start();
  return { calls, handlers, original, start, stop };
}

test("filters Pi's transcript markers without emitting status or changing text", (t) => {
  const h = harness(t);
  assert.deepEqual(h.calls, []);
  assert.deepEqual([...h.handlers.keys()], ["session_start", "session_shutdown"]);
  process.stdout.write("\x1b]133;A\x07User message\x1b]133;B\x07\x1b]133;C\x07");
  assert.equal(h.calls[0].args[0], "User message");
  process.stdout.write("\x1b]133;A\x1b\\Assistant message\x1b]133;B\x1b\\\x1b]133;C\x1b\\");
  assert.equal(h.calls[1].args[0], "Assistant message");
});

test("preserves native status, titles, colours, and unrelated escape sequences", (t) => {
  const h = harness(t);
  const data = "\x1b]7501;state=working:app=pi\x1b\\\x1b]0;project\x07\x1b[31mText\x1b[0m\x1b]133;D;0\x07";
  process.stdout.write(data);
  assert.equal(h.calls[0].args[0], data);
});

test("preserves stream arguments, receiver, backpressure and binary data", (t) => {
  const h = harness(t);
  const callback = () => {};
  assert.equal(process.stdout.write("\x1b]133;A\x07Text", "utf8", callback), false);
  assert.equal(h.calls[0].receiver, process.stdout);
  assert.deepEqual(h.calls[0].args, ["Text", "utf8", callback]);
  const bytes = Buffer.from([0, 255, 127]);
  process.stdout.write(bytes, callback);
  assert.equal(h.calls[1].args[0], bytes);
  assert.equal(h.calls[1].args[1], callback);
});

test("restores stdout on shutdown and does not stack wrappers on repeated starts", (t) => {
  const h = harness(t);
  const first = process.stdout.write;
  h.start();
  assert.notEqual(process.stdout.write, first);
  process.stdout.write("\x1b]133;A\x07Text");
  assert.equal(h.calls.length, 1);
  h.stop();
  assert.equal(process.stdout.write, h.original);
  h.stop();
  assert.equal(process.stdout.write, h.original);
});

test("keeps later wrappers installed and disables its own filter on shutdown", (t) => {
  const h = harness(t);
  const inner = process.stdout.write;
  const outer = ((...args) => inner.apply(process.stdout, args));
  process.stdout.write = outer;
  h.stop();
  assert.equal(process.stdout.write, outer);
  const text = "\x1b]133;A\x07Unfiltered after shutdown";
  process.stdout.write(text);
  assert.equal(h.calls[0].args[0], text);
});

for (const options of [{ mode: "rpc" }, { mode: "json" }, { mode: "print" }, { tty: false }, { session: "" }, { block: "" }]) {
  test(`does not intercept output outside interactive Rex: ${JSON.stringify(options)}`, (t) => {
    const h = harness(t, options);
    assert.equal(process.stdout.write, h.original);
    const data = "\x1b]133;A\x07Text";
    process.stdout.write(data);
    assert.equal(h.calls[0].args[0], data);
  });
}
