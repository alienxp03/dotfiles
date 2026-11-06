import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { loadPresets } from "../extensions/model-presets.ts";

const shared = [{ label: "Shared", provider: "test", modelId: "shared", thinkingLevel: "high" }];
const local = [{ label: "Local", provider: "zai", modelId: "glm-5.3", thinkingLevel: "max" }];

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), "model-presets-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  writeFileSync(join(dir, "model-presets.json"), JSON.stringify(shared));
  return dir;
}

test("uses shared presets when no local override exists", (t) => {
  assert.deepEqual(loadPresets(fixture(t)), shared);
});

test("local presets replace shared presets and support max thinking", (t) => {
  const dir = fixture(t);
  writeFileSync(join(dir, "model-presets.local.json"), JSON.stringify(local));
  assert.deepEqual(loadPresets(dir), local);
});

test("picks up config edits without restarting", (t) => {
  const dir = fixture(t);
  assert.deepEqual(loadPresets(dir), shared);
  writeFileSync(join(dir, "model-presets.local.json"), JSON.stringify(local));
  assert.deepEqual(loadPresets(dir), local);
});

test("rejects malformed or invalid overrides instead of silently falling back", (t) => {
  const dir = fixture(t);
  for (const value of ["{", "[]", "null", "[null]", JSON.stringify([{ ...local[0], thinkingLevel: "invalid" }]), JSON.stringify([{ ...local[0], modelId: "" }])]) {
    writeFileSync(join(dir, "model-presets.local.json"), value);
    assert.throws(() => loadPresets(dir));
  }
});

test("reports missing shared config", (t) => {
  const dir = fixture(t);
  rmSync(join(dir, "model-presets.json"));
  assert.throws(() => loadPresets(dir), /ENOENT/);
});
