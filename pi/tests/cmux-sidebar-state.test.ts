import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { test } from "node:test";
import { CmuxSidebarState } from "../extensions/cmux-status/sidebar-state.ts";

async function fixture(t) {
  const directory = await mkdtemp(resolve("aux/cmux-sidebar-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const alive = new Set([101, 202]);
  const pane = (surfaceId, pid = 101, workspaceId = "workspace-test") => new CmuxSidebarState({
    stateDirectory: directory, workspaceId, surfaceId, sessionId: `session-${surfaceId}`, pid,
  }, pid => alive.has(pid));
  return { directory, alive, pane };
}

test("left Running survives right completion, acknowledgment, and close", async t => {
  const { pane } = await fixture(t);
  const left = pane("left");
  const right = pane("right", 202);
  assert.equal(await left.publish("running"), "running");
  assert.equal(await right.publish("done"), "running");
  assert.equal(await right.publish("idle"), "running");
  assert.equal(await right.remove(), "running");
  assert.equal(await left.publish("done"), "done");
});

test("a real input wait takes precedence over another running pane", async t => {
  const { pane } = await fixture(t);
  const left = pane("left");
  const right = pane("right", 202);
  await left.publish("running");
  assert.equal(await right.publish("waiting"), "waiting");
  assert.equal(await left.publish("running"), "waiting");
  assert.equal(await right.publish("idle"), "running");
  assert.equal(await left.publish("idle"), "idle");
});

test("errors remain visible over running siblings, below real input waits", async t => {
  const { pane } = await fixture(t);
  const left = pane("left");
  const right = pane("right", 202);
  await left.publish("error");
  assert.equal(await right.publish("running"), "error");
  assert.equal(await right.publish("waiting"), "waiting");
});

test("unread Done remains visible while a sibling is idle", async t => {
  const { pane } = await fixture(t);
  const left = pane("left");
  const right = pane("right", 202);
  await left.publish("done");
  assert.equal(await right.publish("idle"), "done");
  assert.equal(await left.publish("idle"), "idle");
});

test("different workspaces never share their status", async t => {
  const { pane } = await fixture(t);
  await pane("left", 101, "other-workspace").publish("waiting");
  assert.equal(await pane("right", 202).publish("idle"), "idle");
});

test("dead parents cannot leave a sibling stuck Running", async t => {
  const { pane, alive } = await fixture(t);
  await pane("left").publish("running");
  alive.delete(101);
  assert.equal(await pane("right", 202).publish("idle"), "idle");
});

test("expired heartbeats cannot leave a reused PID stuck Running", async t => {
  const { pane, directory } = await fixture(t);
  await pane("left").publish("running");
  const file = join(directory, "pi-sidebar-status", "workspace-test", "left.json");
  const state = JSON.parse(await readFile(file, "utf8"));
  state.updatedAt = Date.now() - 60_000;
  await writeFile(file, JSON.stringify(state));
  assert.equal(await pane("right", 202).publish("idle"), "idle");
});

test("a replaced session cannot remove its pane's new owner", async t => {
  const { pane } = await fixture(t);
  const old = pane("left");
  const next = pane("left", 202);
  await old.publish("running");
  await next.publish("waiting");
  assert.equal(await old.remove(), "waiting");
  assert.equal(await pane("right").publish("idle"), "waiting");
});

test("damaged snapshots do not hide healthy panes", async t => {
  const { pane, directory } = await fixture(t);
  const left = pane("left");
  await left.publish("running");
  await writeFile(join(directory, "pi-sidebar-status", "workspace-test", "broken.json"), "not json");
  assert.equal(await left.publish("running"), "running");
});

test("closing the last parent removes its snapshot", async t => {
  const { pane } = await fixture(t);
  const left = pane("left");
  await left.publish("running");
  assert.equal(await left.remove(), undefined);
  assert.equal(await left.remove(), undefined);
});
