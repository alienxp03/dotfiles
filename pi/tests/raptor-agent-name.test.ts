import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import install from "../extensions/raptor-agent-name.ts";

function harness(t, { mode = "tui", env = {}, name = undefined } = {}) {
  const root = mkdtempSync(join(tmpdir(), "pi-raptor-name-"));
  const cache = join(root, "cache");
  t.mock.property(process, "env", {
    HOME: join(root, "home"),
    XDG_CACHE_HOME: cache,
    REX_SESSION: "session:test",
    REX_BLOCK: "block:pi",
    ...env,
  });
  const handlers = new Map();
  const timers = [];
  const cleared = [];
  t.mock.method(globalThis, "setInterval", (fn, interval) => {
    const timer = { fn, interval, unrefs: 0, unref() { this.unrefs++; } };
    timers.push(timer);
    return timer;
  });
  t.mock.method(globalThis, "clearInterval", (timer) => cleared.push(timer));
  let uiCalls = 0;
  const ctx = {
    mode,
    sessionManager: { getSessionName: () => name },
    get ui() {
      uiCalls++;
      assert.fail("The bridge must not use UI APIs");
    },
  };
  const stdoutWrite = process.stdout.write;
  install({ on: (event, handler) => handlers.set(event, handler) });
  const start = (reason = "startup") => handlers.get("session_start")({ reason }, ctx);
  const stop = () => handlers.get("session_shutdown")({ reason: "quit" }, ctx);
  const file = () => join(process.env.XDG_CACHE_HOME || join(process.env.HOME, "Library", "Caches"), "raptor", "agents", `pi-${process.pid}.json`);
  t.after(() => {
    stop();
    assert.equal(process.stdout.write, stdoutWrite);
    assert.equal(uiCalls, 0);
    t.mock.restoreAll();
    rmSync(root, { recursive: true, force: true });
  });
  return {
    root, cache, ctx, timers, cleared, start, stop, file,
    read: () => JSON.parse(readFileSync(file(), "utf8")),
    tick: () => timers.at(-1)?.fn(),
    rename(value) {
      name = value;
      handlers.get("session_info_changed")({ name: value }, ctx);
    },
    factory: () => install({ on: (event, handler) => handlers.set(event, handler) }),
  };
}

test("factory allocates no files or timers; startup writes the exact private contract", (t) => {
  const h = harness(t, { name: "test" });
  assert.deepEqual(readdirSync(h.root), []);
  assert.equal(h.timers.length, 0);
  h.rename("test");
  assert.deepEqual(readdirSync(h.root), []);
  h.start();
  const metadata = h.read();
  assert.deepEqual(metadata, {
    pid: process.pid,
    app: "pi",
    name: "test",
    block_id: "block:pi",
    session_id: "session:test",
    updated_at: metadata.updated_at,
  });
  assert.equal(new Date(metadata.updated_at).toISOString(), metadata.updated_at);
  assert.equal(statSync(h.file()).mode & 0o777, 0o600);
  assert.deepEqual(readdirSync(join(h.cache, "raptor", "agents")), [`pi-${process.pid}.json`]);
  assert.equal(h.timers[0].interval, 5000);
  assert.equal(h.timers[0].unrefs, 1);
});

test("rename and clear update immediately; writes replace the file atomically", (t) => {
  const h = harness(t);
  h.start();
  assert.equal(h.read().name, "");
  const original = statSync(h.file()).ino;
  h.rename("test");
  assert.equal(h.read().name, "test");
  assert.notEqual(statSync(h.file()).ino, original);
  h.rename(undefined);
  assert.equal(h.read().name, "");
  h.rename("");
  assert.equal(h.read().name, "");
  assert.equal(statSync(h.file()).mode & 0o777, 0o600);
});

test("heartbeat refreshes metadata every five seconds within the 15-second freshness window", (t) => {
  const h = harness(t, { name: "heartbeat" });
  t.mock.timers.enable({ apis: ["Date"], now: 1_000_000 });
  h.start();
  const first = h.read();
  t.mock.timers.tick(5000);
  h.tick();
  assert.deepEqual(h.read(), { ...first, updated_at: new Date().toISOString() });
  assert.equal(Date.parse(h.read().updated_at) - Date.parse(first.updated_at), 5000);
});

test("shutdown is idempotent and removes only its own file; stopped callbacks do nothing", (t) => {
  const h = harness(t);
  h.start();
  const other = join(h.cache, "raptor", "agents", "pi-other.json");
  writeFileSync(other, "{}");
  h.stop();
  h.stop();
  h.tick();
  h.rename("after shutdown");
  assert.equal(existsSync(h.file()), false);
  assert.equal(existsSync(other), true);
  assert.deepEqual(h.cleared, h.timers);
});

for (const reason of ["reload", "new", "resume", "fork"]) {
  test(`${reason} replaces the timer and restores metadata from the new session`, (t) => {
    const h = harness(t, { name: "old" });
    h.start();
    const oldTimer = h.timers[0];
    h.stop();
    h.factory();
    h.rename("replacement");
    h.start(reason);
    assert.equal(h.read().name, "replacement");
    assert.deepEqual(h.cleared, [oldTimer]);
    h.start(reason);
    assert.equal(h.timers.length, 3);
    assert.deepEqual(h.cleared, h.timers.slice(0, 2));
  });
}

for (const mode of ["rpc", "json", "print"]) {
  test(`does nothing in ${mode} mode`, (t) => {
    const h = harness(t, { mode });
    h.start();
    h.rename("ignored");
    assert.equal(h.timers.length, 0);
    assert.deepEqual(readdirSync(h.root), []);
  });
}

for (const key of ["REX_SESSION", "REX_BLOCK"]) {
  for (const value of [undefined, "", "  "]) {
    test(`does nothing with invalid ${key}=${JSON.stringify(value)}`, (t) => {
      const h = harness(t, { env: { [key]: value } });
      h.start();
      h.rename("ignored");
      assert.equal(h.timers.length, 0);
      assert.deepEqual(readdirSync(h.root), []);
    });
  }
}

test("uses HOME/Library/Caches when XDG_CACHE_HOME is unset", (t) => {
  const h = harness(t, { env: { XDG_CACHE_HOME: undefined } });
  h.start();
  assert.equal(existsSync(join(h.root, "home", "Library", "Caches", "raptor", "agents", `pi-${process.pid}.json`)), true);
});

test("does nothing when no cache root is available", (t) => {
  const h = harness(t, { env: { XDG_CACHE_HOME: undefined, HOME: undefined } });
  h.start();
  assert.equal(h.timers.length, 0);
  assert.deepEqual(readdirSync(h.root), []);
});

test("unwritable cache failures never escape; heartbeat retries after recovery", (t) => {
  const h = harness(t);
  // A file as the cache root fails deterministically, even when tests run as root.
  writeFileSync(h.cache, "not a directory");
  assert.doesNotThrow(() => h.start());
  assert.doesNotThrow(() => h.rename("retry"));
  assert.doesNotThrow(() => h.tick());
  rmSync(h.cache);
  h.tick();
  assert.equal(h.read().name, "retry");
  assert.doesNotThrow(() => h.stop());
});

test("failed atomic replacement removes its temporary file and tolerates cleanup failure", (t) => {
  const h = harness(t);
  h.start();
  rmSync(h.file());
  mkdirSync(h.file());
  assert.doesNotThrow(() => h.rename("cannot replace directory"));
  assert.deepEqual(readdirSync(join(h.cache, "raptor", "agents")), [`pi-${process.pid}.json`]);
  assert.doesNotThrow(() => h.stop());
  assert.doesNotThrow(() => h.stop());
});
