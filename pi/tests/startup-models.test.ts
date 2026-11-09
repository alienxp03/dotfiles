import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

function fixture(t) {
  mkdirSync(join(repo, "aux"), { recursive: true });
  const dir = mkdtempSync(join(repo, "aux/startup-models-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  mkdirSync(join(dir, "pi"));
  mkdirSync(join(dir, "bin"));
  writeFileSync(join(dir, "bin/pi"), '#!/bin/sh\nprintf "%s\\n" "$@"\n', { mode: 0o755 });
  return {
    setConfig: (value) => writeFileSync(join(dir, "pi/startup-models.local.json"), value),
    run: (...args) => spawnSync("zsh", ["-f", "-c", 'compdef() {}; source "$1/config/zsh/functions.zsh"; shift; pi "$@"', "test", repo, ...args], {
      env: { ...process.env, DOTFILES: dir, PATH: `${dir}/bin:${process.env.PATH}` },
      encoding: "utf8",
    }),
  };
}

test("passes arguments unchanged without a local override", (t) => {
  const h = fixture(t);
  const result = h.run("--print", "two words");
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "--print\ntwo words\n");
});

test("loads local model patterns before explicit CLI options", (t) => {
  const h = fixture(t);
  h.setConfig(JSON.stringify(["openai-codex/*", "anthropic/*"]));
  const result = h.run("--models", "explicit/*", "--", "two words");
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "--models\nopenai-codex/*,anthropic/*\n--models\nexplicit/*\n--\ntwo words\n");
});

test("rejects invalid configuration without starting Pi", (t) => {
  const h = fixture(t);
  for (const value of ["{", "[]", "null", "{}", '[null]', '[""]', '["a,b"]', '["a b"]']) {
    h.setConfig(value);
    const result = h.run("--help");
    assert.notEqual(result.status, 0, value);
    assert.equal(result.stdout, "", value);
  }
});

test("reads local changes on each call", (t) => {
  const h = fixture(t);
  h.setConfig('["first/*"]');
  assert.equal(h.run("--help").stdout, "--models\nfirst/*\n--help\n");
  h.setConfig('["second/*"]');
  assert.equal(h.run("--help").stdout, "--models\nsecond/*\n--help\n");
});
