import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "./index.ts";

test("push lifecycle (mock transport; no real notifications)", async () => {
  const handlers = new Map<string, Function>();
  const bus = new Map<string, Function>();
  const sent: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async (_url, init) => {
    sent.push(String(init?.body));
    return new Response("ok");
  }) as typeof fetch;
  const pi = {
    on: (name: string, handler: Function) => handlers.set(name, handler),
    events: { on: (name: string, handler: Function) => bus.set(name, handler) },
  };
  const emit = async (name: string, event: unknown = {}) => handlers.get(name)?.(event, {});
  const start = () => emit("before_agent_start");
  const text = (value: string) => emit("message_end", {
    message: { role: "assistant", content: [{ type: "text", text: value }] },
  });
  const settle = (aborted = false) => emit("agent_settled", { aborted });
  try {
    extension(pi as any);
    await emit("session_start");
    await start();
    await text("Finished.");
    await emit("agent_before_settle", { outcome: "completed" });
    await settle();
    await settle(); // Duplicate settlement must not push twice.
    assert.deepEqual(sent.splice(0), ["Done"]);

    await start();
    await emit("ui_prompt_start");
    bus.get("rpiv:ask-user:blocked")?.({ active: true, toolCallId: "q1" });
    await emit("ui_prompt_start");
    assert.deepEqual(sent.splice(0), ["Input needed"]);
    await emit("ui_prompt_end");
    await text("Which option?");
    await settle();
    assert.deepEqual(sent.splice(0), []); // Still waiting; don't duplicate.
    bus.get("rpiv:ask-user:blocked")?.({ active: false, toolCallId: "q1" });

    await start();
    await emit("ui_prompt_start");
    await emit("ui_prompt_end");
    await emit("ui_prompt_start");
    await emit("ui_prompt_end");
    await text("Finished.");
    await settle();
    assert.deepEqual(sent.splice(0), ["Input needed", "Input needed", "Done"]);

    await start();
    await emit("agent_before_settle", { outcome: "error" });
    await start(); // Automatic recovery must not reset the current run.
    await emit("agent_before_settle", { outcome: "completed" });
    await text("Recovered.");
    await settle();
    assert.deepEqual(sent.splice(0), ["Done"]);

    await start();
    await emit("agent_before_settle", { outcome: "error" });
    await settle();
    assert.deepEqual(sent.splice(0), ["Blocked"]);

    await start();
    await text("Blocked: credentials required.");
    await settle();
    assert.deepEqual(sent.splice(0), ["Blocked"]);

    await start();
    await text("Which branch should I use?");
    await settle();
    assert.deepEqual(sent.splice(0), ["Input needed"]);

    await start();
    await settle(true);
    assert.deepEqual(sent.splice(0), []);
    await emit("session_shutdown");
    await start();
    await settle();
    assert.deepEqual(sent.splice(0), []);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
