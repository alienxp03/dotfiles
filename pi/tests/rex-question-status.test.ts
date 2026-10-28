import assert from "node:assert/strict";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import { test } from "node:test";
import install from "../extensions/rex-question-status.ts";

const report = (state, extra = "") => `\x1b]7501;state=${state}:app=pi${extra}\x1b\\`;

function harness(t, { mode = "tui", tty = true, rex = true, idle = true } = {}) {
  const handlers = new Map();
  const events = new Map();
  const direct = [];
  const output = [];
  const saved = { REX_SESSION: process.env.REX_SESSION, REX_BLOCK: process.env.REX_BLOCK };
  const descriptor = Object.getOwnPropertyDescriptor(process.stdout, "isTTY");
  process.env.REX_SESSION = rex ? "session:test" : "";
  process.env.REX_BLOCK = rex ? "block:test" : "";
  Object.defineProperty(process.stdout, "isTTY", { configurable: true, value: tty });
  t.mock.method(fs, "writeSync", (fd, data) => {
    assert.equal(fd, process.stdout.fd);
    direct.push(data);
    return Buffer.byteLength(data);
  });
  syncBuiltinESMExports();
  const original = t.mock.method(process.stdout, "write", function (...args) {
    output.push({ receiver: this, args });
    return false;
  });
  install({
    on: (name, handler) => handlers.set(name, handler),
    events: { on: (name, handler) => events.set(name, handler) },
  });
  const start = () => handlers.get("session_start")({}, { mode, isIdle: () => idle });
  const stop = () => handlers.get("session_shutdown")();
  const event = (data) => events.get("rpiv:ask-user:blocked")(data);
  const wait = (toolCallId, active = true) => event({ toolCallId, active });
  start();
  t.after(() => {
    stop();
    t.mock.restoreAll();
    syncBuiltinESMExports();
    if (descriptor) Object.defineProperty(process.stdout, "isTTY", descriptor);
    else delete process.stdout.isTTY;
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  return { direct, output, original, start, stop, wait, event };
}

test("uses Pi's root record for Blocked and restores native Working after an answer", (t) => {
  const h = harness(t);
  assert.deepEqual(h.direct, []);
  process.stdout.write(report("working"));
  h.wait("question-1");
  assert.match(h.direct[0], /state=blocked:kind=question:app=pi/);
  assert.ok(!h.direct[0].includes("id="));
  const message = h.direct[0].match(/:msg=([^\x1b]+)/)[1];
  assert.equal(Buffer.from(message, "base64").toString("utf8"), "Needs input");
  h.wait("question-1", false);
  assert.equal(h.direct[1], report("working"));
  process.stdout.write(report("done"));
  assert.equal(h.output.at(-1).args[0], report("done"));
});

test("handles concurrent questions and duplicate events without repeated notifications", (t) => {
  const h = harness(t);
  h.wait("q1"); h.wait("q1"); h.wait("q2");
  h.wait("q1", false); h.wait("missing", false);
  assert.equal(h.direct.length, 1);
  h.wait("q2", false); h.wait("q2", false);
  assert.deepEqual(h.direct.slice(1), [report("idle")]);
});

test("keeps Blocked visible during native updates and restores the latest native report", (t) => {
  const h = harness(t);
  h.wait("q");
  const latest = report("error", ":msg=RmFpbGVk");
  process.stdout.write(`before${report("working")}middle${latest}after`);
  assert.equal(h.output.at(-1).args[0], "beforemiddleafter");
  assert.equal(h.direct.length, 1);
  h.wait("q", false);
  assert.equal(h.direct.at(-1), latest);
});

test("preserves other applications, child records, bytes and stream arguments", (t) => {
  const h = harness(t);
  h.wait("q");
  const text = "\x1b]7501;state=working:app=codex\x1b\\" + report("working", ":id=child");
  const callback = () => {};
  assert.equal(process.stdout.write(text, "utf8", callback), false);
  assert.equal(h.output[0].receiver, process.stdout);
  assert.deepEqual(h.output[0].args, [text, "utf8", callback]);
  const bytes = Buffer.from([0, 255, 127]);
  process.stdout.write(bytes);
  assert.equal(h.output.at(-1).args[0], bytes);
});

test("accepts BEL reports and restores an idle dialog or a mid-run reload correctly", (t) => {
  const h = harness(t, { idle: false });
  h.wait("q"); h.wait("q", false);
  assert.equal(h.direct.at(-1), report("working"));
  const idle = "\x1b]7501;state=idle:app=pi\x07";
  process.stdout.write(idle);
  h.wait("q"); h.wait("q", false);
  assert.equal(h.direct.at(-1), idle);
});

test("ignores malformed events", (t) => {
  const h = harness(t);
  for (const data of [null, true, {}, { active: true }, { active: "true", toolCallId: "q" }, { active: true, toolCallId: "" }]) h.event(data);
  assert.deepEqual(h.direct, []);
});

test("restores native status and stdout once on shutdown", (t) => {
  const h = harness(t);
  process.stdout.write(report("working"));
  h.wait("q"); h.stop(); h.stop();
  assert.deepEqual(h.direct.slice(1), [report("working")]);
  assert.equal(process.stdout.write, h.original);
  h.wait("late");
  assert.equal(h.direct.length, 2);
});

test("does not remove a later stdout wrapper", (t) => {
  const h = harness(t);
  const inner = process.stdout.write;
  const outer = ((...args) => inner.apply(process.stdout, args));
  process.stdout.write = outer;
  h.stop();
  assert.equal(process.stdout.write, outer);
  process.stdout.write(report("done"));
  assert.equal(h.output.at(-1).args[0], report("done"));
});

for (const options of [{ mode: "rpc" }, { mode: "json" }, { mode: "print" }, { tty: false }, { rex: false }]) {
  test(`no interception outside interactive Rex: ${JSON.stringify(options)}`, (t) => {
    const h = harness(t, options);
    h.wait("q"); h.wait("q", false);
    assert.equal(process.stdout.write, h.original);
    assert.deepEqual(h.direct, []);
  });
}
