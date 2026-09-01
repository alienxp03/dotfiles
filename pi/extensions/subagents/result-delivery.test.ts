import assert from "node:assert/strict";
import test from "node:test";
import { buildSubagentSpawnResult } from "./src/prompt.ts";
import { createDeferredResultDelivery } from "./src/result-delivery.ts";

test("a result consumed by a later wait is not delivered", () => {
  const delivery = createDeferredResultDelivery<{
    id: string;
    output: string;
  }>();

  delivery.defer({ id: "sa-1", output: "done" });
  delivery.consume(["sa-1"]);

  assert.deepEqual(delivery.drain(), []);
});

test("unconsumed results are delivered once in settlement order", () => {
  const delivery = createDeferredResultDelivery<{ id: string }>();
  const first = { id: "sa-1" };
  const second = { id: "sa-2" };

  delivery.defer(first);
  delivery.defer(second);

  assert.deepEqual(delivery.drain(), [first, second]);
  assert.deepEqual(delivery.drain(), []);
});

test("spawn guidance prefers background continuation over blocking wait", () => {
  const message = buildSubagentSpawnResult({
    id: "sa-1",
    title: "inspect",
    harness: "codex",
    modelLabel: "gpt-5.6-sol",
    cwd: "/tmp/project",
  });

  assert.match(message, /live activity appears above the editor/);
  assert.match(message, /delivered automatically/);
  assert.match(message, /hard dependency/);
  assert.doesNotMatch(message, /to block for it/);
});
