import assert from "node:assert/strict";
import test from "node:test";
import {
  createDirectSubagentAutocomplete,
  directSubagentTagPrefix,
  isDirectSubagentTagDraft,
  parseDirectSubagentPrompt,
} from "./src/direct.ts";
import type { SubagentSnapshot } from "./src/domain.ts";

const snapshots = [
  { id: "sa-1", title: "readonly-git-2", status: "running", backend: "pi" },
  { id: "sa-2", title: "code review", status: "done", backend: "codex" },
] as unknown as SubagentSnapshot[];

test("parses direct subagent prompts and quoted names", () => {
  assert.deepEqual(parseDirectSubagentPrompt("@readonly-git-2 inspect the diff"), {
    reference: "readonly-git-2",
    prompt: "inspect the diff",
  });
  assert.deepEqual(parseDirectSubagentPrompt('@"code review" summarize this'), {
    reference: "code review",
    prompt: "summarize this",
  });
  assert.equal(parseDirectSubagentPrompt("@readonly-git-2"), undefined);
});

test("completes direct subagent tags and preserves the prompt suffix", async () => {
  assert.equal(directSubagentTagPrefix("@readonly"), "@readonly");
  assert.equal(directSubagentTagPrefix("ask @readonly"), undefined);
  assert.equal(isDirectSubagentTagDraft("@readonly"), true);
  assert.equal(isDirectSubagentTagDraft("@readonly "), true);
  assert.equal(isDirectSubagentTagDraft('@"code review" '), true);
  assert.equal(isDirectSubagentTagDraft("@readonly inspect"), false);

  const fallback = {
    getSuggestions: async () => null,
    applyCompletion: () => ({ lines: ["fallback"], cursorLine: 0, cursorCol: 8 }),
  } as any;
  const provider = createDirectSubagentAutocomplete(fallback, async () => snapshots);
  const suggestions = await provider.getSuggestions(
    ["@readonly"],
    0,
    9,
    { signal: new AbortController().signal },
  );
  assert.equal(suggestions?.items[0]?.value, "@readonly-git-2");

  const applied = provider.applyCompletion(
    ["@readonly inspect the diff"],
    0,
    9,
    suggestions!.items[0]!,
    "@readonly",
  );
  assert.deepEqual(applied, {
    lines: ["@readonly-git-2 inspect the diff"],
    cursorLine: 0,
    cursorCol: 15,
  });
});
