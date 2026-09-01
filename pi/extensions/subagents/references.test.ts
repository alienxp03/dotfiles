import assert from "node:assert/strict";
import test from "node:test";
import { resolveSubagentReferences } from "./src/references.ts";

const snapshots = [
  { id: "sa-1", title: "review-api" },
  { id: "sa-2", title: "check-tests" },
  { id: "sa-3", title: "review-api" },
];

test("subagent references resolve ids and unique human-readable names", () => {
  assert.deepEqual(
    resolveSubagentReferences(["check-tests", "sa-1", "check-tests"], snapshots),
    { ids: ["sa-2", "sa-1"], unknown: [], ambiguous: [] },
  );
});

test("duplicate human-readable names are reported as ambiguous", () => {
  assert.deepEqual(resolveSubagentReferences(["review-api"], snapshots), {
    ids: [],
    unknown: [],
    ambiguous: [{ reference: "review-api", ids: ["sa-1", "sa-3"] }],
  });
});

test("unknown subagent references are reported without guessing", () => {
  assert.deepEqual(resolveSubagentReferences(["missing"], snapshots), {
    ids: [],
    unknown: ["missing"],
    ambiguous: [],
  });
});
