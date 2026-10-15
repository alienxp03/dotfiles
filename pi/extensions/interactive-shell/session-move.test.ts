import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import test, { type TestContext } from "node:test";
import { prepareSessionMove } from "./session-move.ts";

function fixture(t: TestContext) {
	mkdirSync("aux", { recursive: true });
	const root = mkdtempSync(resolve("aux/session-move-test-"));
	t.after(() => rmSync(root, { recursive: true, force: true }));
	const source = join(root, "session.jsonl");
	const content = `${JSON.stringify({ type: "session", id: "same-id", cwd: "/old" })}\n{"type":"message","id":"entry"}\n`;
	writeFileSync(source, content);
	return { root, source, content, targetDir: join(root, "target") };
}

test("move keeps ID and entries; source is removed only after completion", (t) => {
	const { source, content, targetDir } = fixture(t);
	const move = prepareSessionMove(source, targetDir, "/new worktree");
	assert.equal(readFileSync(source, "utf8"), content);
	const [header, ...entries] = readFileSync(move.target, "utf8").split("\n");
	assert.deepEqual(JSON.parse(header), { type: "session", id: "same-id", cwd: "/new worktree" });
	assert.deepEqual(entries, content.split("\n").slice(1));
	move.complete();
	assert.equal(existsSync(source), false);
	assert.equal(existsSync(move.target), true);
});

test("cancel removes the copy and keeps the original", (t) => {
	const { source, content, targetDir } = fixture(t);
	const move = prepareSessionMove(source, targetDir, "/new");
	move.cancel();
	assert.equal(existsSync(move.target), false);
	assert.equal(readFileSync(source, "utf8"), content);
});

test("destination collision never overwrites an existing session", (t) => {
	const { source, targetDir } = fixture(t);
	const move = prepareSessionMove(source, targetDir, "/new");
	const copy = readFileSync(move.target, "utf8");
	assert.throws(() => prepareSessionMove(source, targetDir, "/other"), /EEXIST/);
	assert.equal(readFileSync(move.target, "utf8"), copy);
	assert.equal(existsSync(source), true);
});

test("source changes during replacement preserve both files", (t) => {
	const { source, content, targetDir } = fixture(t);
	const move = prepareSessionMove(source, targetDir, "/new");
	writeFileSync(source, `${content}{"type":"custom"}\n`);
	assert.throws(() => move.complete(), /Both files were kept/);
	assert.equal(existsSync(source), true);
	assert.equal(existsSync(move.target), true);
});

test("invalid header leaves source untouched", (t) => {
	const { source, targetDir } = fixture(t);
	writeFileSync(source, "{\"type\":\"message\"}\n");
	assert.throws(() => prepareSessionMove(source, targetDir, "/new"), /invalid header/);
	assert.equal(existsSync(source), true);
	assert.equal(existsSync(targetDir), false);
});
