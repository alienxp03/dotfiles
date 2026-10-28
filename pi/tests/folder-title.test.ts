import assert from "node:assert/strict";
import { test } from "node:test";
import install from "../extensions/folder-title.ts";

function harness(t, mode = "tui") {
  const handlers = new Map();
  const events = new Map();
  const titles = [];
  let tick;
  t.mock.method(globalThis, "setInterval", (fn) => { tick = fn; return { unref() {} }; });
  t.mock.method(globalThis, "clearInterval", () => {});
  install({
    on: (name, handler) => handlers.set(name, handler),
    events: { on: (name, handler) => events.set(name, handler) },
  });
  const start = () => handlers.get("session_start")({}, {
    mode, cwd: "/test/.dotfiles", ui: { setTitle: (title) => titles.push(title) },
  });
  const status = (state) => events.get("rex:status")({ state });
  start();
  t.after(() => { handlers.get("session_shutdown")(); t.mock.restoreAll(); });
  return { titles, status, start, tick: () => tick?.(), stop: () => handlers.get("session_shutdown")() };
}

test("adds compact Rex status symbols and keeps them through periodic title updates", (t) => {
  const h = harness(t);
  assert.equal(h.titles.at(-1), ".dotfiles");
  for (const [state, prefix] of [["working", "ϟ"], ["blocked", "?"], ["done", "✓"], ["error", "×"]]) {
    h.status(state);
    assert.equal(h.titles.at(-1), `${prefix} .dotfiles`);
    h.tick();
    assert.equal(h.titles.at(-1), `${prefix} .dotfiles`);
  }
  h.status("idle");
  assert.equal(h.titles.at(-1), ".dotfiles");
  h.status("working");
  h.status("clear");
  assert.equal(h.titles.at(-1), ".dotfiles");
});

test("ignores invalid states and resets across session replacement", (t) => {
  const h = harness(t);
  h.status("working");
  h.status("constructor");
  assert.equal(h.titles.at(-1), "ϟ .dotfiles");
  h.stop();
  const count = h.titles.length;
  h.status("done");
  assert.equal(h.titles.length, count);
  h.start();
  assert.equal(h.titles.at(-1), ".dotfiles");
});

test("does not write terminal titles in RPC mode", (t) => {
  const h = harness(t, "rpc");
  h.status("working");
  assert.deepEqual(h.titles, []);
});
