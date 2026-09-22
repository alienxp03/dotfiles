import assert from "node:assert/strict";
import { mock, test } from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { SubagentSnapshot } from "./src/domain.ts";
import { SubagentActivityWidget } from "./src/ui/activity.ts";

test("prompts hide the preview until a new spawn, without restoring settled history", async () => {
  const snapshots: SubagentSnapshot[] = [];
  const listeners = new Set<() => void>();
  const notify = () => { for (const listener of [...listeners]) listener(); };
  const manager = {
    view: {
      list: () => snapshots,
      subscribe: (listener: () => void) => {
        listeners.add(listener);
        return () => listeners.delete(listener);
      },
      setOnSettled: () => {},
      stats: () => ({ totalAgents: snapshots.length, agentTimeMs: 0, wallTimeMs: 0 }),
    },
    spawn: (_backend: string, task: { title: string }) => {
      const snap = {
        id: `sa-${snapshots.length + 1}`, title: task.title,
        origin: "model", backend: "pi", status: "running",
        createdAt: snapshots.length + 1, lastActivityAt: 1,
        cwd: process.cwd(), prompt: "test", meta: { backend: "pi" },
        usage: {}, transcript: [], liveTools: [], queued: [], finalText: "", turns: 0,
      } as SubagentSnapshot;
      snapshots.push(snap);
      notify();
      return snap;
    },
  };
  const runtimeMock = mock.module("./src/runtime.ts", {
    namedExports: {
      createSubagentRuntime: () => ({ runPromise: async () => manager, dispose: async () => {} }),
      runTool: async (_runtime: unknown, result: unknown) => result,
    },
  });
  const { default: extension } = await import("./index.ts");
  const events = new Map<string, (...args: any[]) => any>();
  const tools = new Map<string, any>();
  let widget: SubagentActivityWidget | undefined;
  let installs = 0;
  const ui = {
    addAutocompleteProvider: () => {},
    setWidget: (_id: string, factory: any) => {
      widget?.dispose();
      widget = factory?.({ requestRender: () => {}, addInputListener: () => () => {} }, {
        fg: (_color: string, text: string) => text,
      });
      if (factory) installs++;
    },
  };
  const ctx = { hasUI: true, ui, cwd: process.cwd(), isProjectTrusted: () => true };
  extension({
    on: (name: string, handler: any) => events.set(name, handler),
    registerTool: (tool: any) => tools.set(tool.name, tool),
    registerCommand: () => {}, registerMessageRenderer: () => {}, registerEntryRenderer: () => {},
    getThinkingLevel: () => "medium",
  } as unknown as ExtensionAPI);
  const spawn = (name: string) => tools.get("subagent_spawn").execute("call", {
    name, harness: "pi", prompt: "test",
  }, undefined, undefined, ctx);
  try {
    await events.get("session_start")!({}, ctx);
    await spawn("first-old");
    await spawn("second-old");
    await events.get("input")!({ source: "interactive", text: "follow up", streamingBehavior: "followUp" }, ctx);
    assert.equal(widget, undefined);
    notify();
    assert.equal(widget, undefined, "running updates must not restore the preview");
    for (let i = 0; i < snapshots.length; i++) snapshots[i] = { ...snapshots[i], status: "done" };
    notify();
    assert.equal(widget, undefined, "settlement must not restore the preview");
    await events.get("input")!({ source: "interactive", text: "next task" }, ctx);
    await spawn("new-agent");
    assert.equal(installs, 2);
    const rendered = widget!.render(100).join("\n");
    assert.match(rendered, /new-agent/);
    assert.doesNotMatch(rendered, /first-old|second-old|\+1 more/);
    assert.equal(snapshots.length, 3, "history remains available");
    await events.get("input")!({ source: "extension", text: "automatic result" }, ctx);
    assert.ok(widget, "automatic messages must not hide the preview");
    snapshots[2] = { ...snapshots[2], status: "done" };
    notify();
    await events.get("input")!({ source: "interactive", text: "thanks" }, ctx);
    notify();
    assert.equal(widget, undefined, "a new prompt also hides completed previews");
  } finally {
    await events.get("session_shutdown")!({}, ctx);
    runtimeMock.restore();
  }
});
