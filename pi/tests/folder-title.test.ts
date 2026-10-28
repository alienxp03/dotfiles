import assert from "node:assert/strict";
import { test } from "node:test";
import install from "../extensions/folder-title.ts";

function harness(t, { mode = "tui", cwd = "/test/.dotfiles" } = {}) {
  const handlers = new Map();
  const titles = [];
  const cleared = [];
  const timers = [];
  t.mock.method(globalThis, "setInterval", (fn, interval) => {
    const timer = { fn, interval, unref() {} };
    timers.push(timer);
    return timer;
  });
  t.mock.method(globalThis, "clearInterval", (timer) => cleared.push(timer));
  install({ on: (name, handler) => handlers.set(name, handler) });
  const ctx = { mode, cwd, ui: { setTitle: (title) => titles.push(title) } };
  const start = () => handlers.get("session_start")({}, ctx);
  const stop = () => handlers.get("session_shutdown")();
  start();
  t.after(() => { stop(); t.mock.restoreAll(); });
  return { titles, timers, cleared, start, stop, ctx, tick: () => timers.at(-1)?.fn() };
}

test("uses the plain folder title at startup and on periodic updates", (t) => {
  const h = harness(t);
  assert.deepEqual(h.titles, [".dotfiles"]);
  assert.equal(h.timers[0].interval, 1000);
  h.tick();
  assert.deepEqual(h.titles, [".dotfiles", ".dotfiles"]);
  h.ctx.cwd = "/test/another-project";
  h.tick();
  assert.equal(h.titles.at(-1), "another-project");
});

test("cleans up the timer across session replacement and shutdown", (t) => {
  const h = harness(t);
  const first = h.timers[0];
  h.start();
  assert.deepEqual(h.cleared, [first]);
  h.stop();
  assert.deepEqual(h.cleared, h.timers);
  h.stop();
  assert.equal(h.cleared.length, 2);
});

test("falls back to the full path for the filesystem root", (t) => {
  const h = harness(t, { cwd: "/" });
  assert.deepEqual(h.titles, ["/"]);
});

test("does not write titles or start a timer in RPC mode", (t) => {
  const h = harness(t, { mode: "rpc" });
  assert.deepEqual(h.titles, []);
  assert.deepEqual(h.timers, []);
});
