import assert from "node:assert/strict";
import * as childProcess from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { registerHooks, syncBuiltinESMExports } from "node:module";
import { join, resolve } from "node:path";
import test from "node:test";

// Reuse the SDK dependency already installed for the subagents extension.
const sdkUrl = new URL("../subagents/node_modules/@earendil-works/pi-coding-agent/dist/index.js", import.meta.url).href;
const { SessionManager } = await import(sdkUrl);
const hook = registerHooks({
	resolve(specifier, context, next) {
		return specifier === "@earendil-works/pi-coding-agent"
			? { url: sdkUrl, shortCircuit: true }
			: next(specifier, context);
	},
});
const { default: install } = await import("../interactive-shell.ts");
hook.deregister();

function harness(t, { idle = true, pending = false, changeWorktree = false, confirm = true, busyOnConfirm = false } = {}) {
	mkdirSync("aux", { recursive: true });
	const root = mkdtempSync(resolve("aux/lazygit-command-"));
	const selected = join(root, "selected-worktree");
	mkdirSync(selected);
	const source = join(root, "session.jsonl");
	const targetDir = join(root, "target-sessions");
	writeFileSync(source, `${JSON.stringify({ type: "session", id: "session-test", cwd: root })}\n`);
	const calls = [];
	const notices = [];
	const confirmations = [];
	const switches = [];
	const commands = new Map();
	const shortcuts = new Map();
	const messages = [];
	t.mock.method(SessionManager, "create", () => ({ getSessionDir: () => targetDir }));
	t.mock.method(childProcess.default, "spawnSync", (shell, args, options) => {
		calls.push({ shell, args, options });
		if (changeWorktree) writeFileSync(options.env.LAZYGIT_NEW_DIR_FILE, `${selected}\n`);
		return { status: 0 };
	});
	const stdoutWrite = process.stdout.write.bind(process.stdout);
	t.mock.method(process.stdout, "write", (text, ...args) => text === "\x1b[2J\x1b[H" ? true : stdoutWrite(text, ...args));
	syncBuiltinESMExports();
	t.after(() => {
		t.mock.restoreAll();
		syncBuiltinESMExports();
		rmSync(root, { recursive: true, force: true });
	});

	install({
		registerCommand: (name, command) => commands.set(name, command),
		registerShortcut: (name, shortcut) => shortcuts.set(name, shortcut),
		sendUserMessage: (text) => messages.push(text),
		on() {},
	});
	const ctx = {
		mode: "tui", cwd: root,
		isIdle: () => idle,
		hasPendingMessages: () => pending,
		sessionManager: { getSessionFile: () => source },
		ui: {
			notify: (message, level) => notices.push({ message, level }),
			custom: factory => new Promise(done => factory({ stop() {}, start() {}, requestRender() {} }, {}, {}, done)),
			confirm: async (...args) => { confirmations.push(args); if (busyOnConfirm) idle = false; return confirm; },
		},
		switchSession: async (target, options) => {
			switches.push(target);
			await options.withSession({ ui: ctx.ui });
			return { cancelled: false };
		},
	};
	return { calls, notices, confirmations, switches, messages, source, selected,
		run: () => commands.get("lazygit-session").handler("", ctx),
		shortcut: () => shortcuts.get("ctrl+g").handler(ctx) };
}

test("Ctrl+G dispatches LazyGit while Pi is busy", async t => {
	const h = harness(t, { idle: false });
	await h.shortcut();
	assert.deepEqual(h.messages, ["/lazygit-session"]);
	await h.run();
	assert.equal(h.calls.length, 1);
	assert.deepEqual(h.calls[0].args, ["-c", "lazygit"]);
	assert.equal(h.notices.length, 0);
});

test("busy Pi can inspect Git but cannot move its session", async t => {
	const h = harness(t, { idle: false, changeWorktree: true });
	await h.run();
	assert.equal(h.calls.length, 1);
	assert.equal(h.confirmations.length, 0);
	assert.equal(h.switches.length, 0);
	assert.equal(h.notices[0].message, "Pi is busy. Session was not moved.");
	assert.equal(existsSync(h.source), true);
});

test("queued prompts block only session moves, not opening LazyGit", async t => {
	const h = harness(t, { pending: true, changeWorktree: true });
	await h.run();
	assert.equal(h.calls.length, 1);
	assert.equal(h.confirmations.length, 0);
	assert.equal(h.switches.length, 0);
	assert.equal(existsSync(h.source), true);
});

test("idle Pi can still move after confirmation", async t => {
	const h = harness(t, { changeWorktree: true });
	await h.run();
	assert.equal(h.confirmations.length, 1);
	assert.equal(h.switches.length, 1);
	assert.equal(existsSync(h.source), false);
	assert.equal(JSON.parse(readFileSync(h.switches[0], "utf8")).cwd, h.selected);
});

test("a new run during confirmation blocks the session move", async t => {
	const h = harness(t, { changeWorktree: true, busyOnConfirm: true });
	await h.run();
	assert.equal(h.confirmations.length, 1);
	assert.equal(h.switches.length, 0);
	assert.equal(existsSync(h.source), true);
});

test("declining a session move keeps the original session", async t => {
	const h = harness(t, { changeWorktree: true, confirm: false });
	await h.run();
	assert.equal(h.switches.length, 0);
	assert.equal(existsSync(h.source), true);
});

test("repeated shortcuts do not open two LazyGit instances", async t => {
	const h = harness(t, { idle: false });
	await Promise.all([h.run(), h.run()]);
	assert.equal(h.calls.length, 1);
});
