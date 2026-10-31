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

function harness(t, { idle = true, pending = false, changeWorktree = false, confirm = true, busyOnConfirm = false, rex = false, rexFailure = false, waitCode = 0, ghCode = 0 } = {}) {
	const savedEnv = { ...process.env };
	if (rex) {
		process.env.REX_SESSION = "session:test";
		process.env.REX_BLOCK = "block:pi";
	} else {
		delete process.env.REX_SESSION;
		delete process.env.REX_BLOCK;
	}
	t.after(() => { process.env = savedEnv; });
	mkdirSync("aux", { recursive: true });
	const root = mkdtempSync(resolve("aux/lazygit-command-"));
	const selected = join(root, "selected-worktree");
	mkdirSync(selected);
	const source = join(root, "session.jsonl");
	const targetDir = join(root, "target-sessions");
	writeFileSync(source, `${JSON.stringify({ type: "session", id: "session-test", cwd: root })}\n`);
	const calls = [];
	const rexCalls = [];
	const notices = [];
	const confirmations = [];
	const switches = [];
	const commands = new Map();
	const shortcuts = new Map();
	const messages = [];
	const events = new Map();
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
		exec: async (command, args, options) => {
			rexCalls.push({ command, args, options });
			if (command === "gh") return { code: ghCode, stdout: "42\n", stderr: ghCode ? "No current PR" : "" };
			assert.equal(command, "rex");
			if (rexFailure) return { code: 1, stderr: "Rex unavailable", stdout: "" };
			if (args[0] === "block") return { code: 0, stdout: JSON.stringify({ block: { window_id: "window:pi" } }) };
			if (args.includes("session.new_layer")) {
				const payload = JSON.parse(args.at(-1));
				if (changeWorktree) writeFileSync(payload.layout.block.options.command[1].slice("LAZYGIT_NEW_DIR_FILE=".length), `${selected}\n`);
				return { code: 0, stdout: JSON.stringify({ layer_id: "layer:git", block_ids: ["block:git"] }) };
			}
			return { code: args[0] === "wait" ? waitCode : 0, stdout: "{}", stderr: "" };
		},
		registerCommand: (name, command) => commands.set(name, command),
		registerShortcut: (name, shortcut) => shortcuts.set(name, shortcut),
		sendUserMessage: (text) => messages.push(text),
		on: (name, handler) => events.set(name, handler),
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
	return { calls, rexCalls, notices, confirmations, switches, messages, source, selected,
		run: () => commands.get("lazygit-session").handler("", ctx),
		shortcut: () => shortcuts.get("ctrl+g").handler(ctx),
		neovim: () => shortcuts.get("ctrl+q").handler(ctx),
		tuicr: (pr = false) => shortcuts.get(pr ? "ctrl+shift+t" : "ctrl+t").handler(ctx),
		bash: command => events.get("user_bash")({ command }, ctx) };
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

test("Rex opens LazyGit in a focused floating layer in Pi's own window", async t => {
	const h = harness(t, { rex: true, idle: false });
	await h.run();
	assert.equal(h.calls.length, 0, "does not suspend Pi or start a local terminal command");
	assert.equal(h.rexCalls.length, 4);
	assert.deepEqual(h.rexCalls[0].args, ["block", "inspect", "block:pi", "-s", "session:test", "--json"]);
	const payload = JSON.parse(h.rexCalls[1].args.at(-1));
	assert.equal(payload.window_id, "window:pi");
	assert.equal(payload.focus, true);
	assert.deepEqual(payload.bounds, [0.05, 0.05, 0.9, 0.9]);
	assert.equal(payload.layout.block.options.cwd, h.rexCalls[1].options.cwd);
	assert.deepEqual(payload.layout.block.options.command.slice(2), ["lazygit"]);
	assert.equal(payload.layout.block.options.exit.on_completion, false);
	assert.equal(existsSync(payload.layout.block.options.command[1].slice("LAZYGIT_NEW_DIR_FILE=".length).replace(/\/newdir$/, "")), false);
	assert.equal(h.rexCalls[2].args[0], "wait");
	assert.ok(h.rexCalls[3].args.includes("session.close_layer"));
});

test("Rex preserves the confirmed worktree session move", async t => {
	const h = harness(t, { rex: true, changeWorktree: true });
	await h.run();
	assert.equal(h.switches.length, 1);
	assert.equal(existsSync(h.source), false);
});

test("Rex failure reports an error without opening a second terminal", async t => {
	const h = harness(t, { rex: true, rexFailure: true });
	await h.run();
	assert.equal(h.calls.length, 0);
	assert.equal(h.notices[0].level, "error");
	assert.match(h.notices[0].message, /Rex unavailable/);
});

test("closing Rex LazyGit unsuccessfully cleans up without moving the session", async t => {
	const h = harness(t, { rex: true, changeWorktree: true, waitCode: 1 });
	await h.run();
	assert.equal(h.switches.length, 0);
	assert.ok(h.rexCalls.at(-1).args.includes("session.close_layer"));
});

test("Ctrl+Q opens Neovim in a Rex floating terminal while Pi is busy", async t => {
	const h = harness(t, { rex: true, idle: false });
	await h.neovim();
	assert.equal(h.calls.length, 0);
	const payload = JSON.parse(h.rexCalls[1].args.at(-1));
	assert.equal(payload.window_id, "window:pi");
	assert.equal(payload.focus, true);
	assert.equal(payload.layout.block.label, "Neovim");
	assert.deepEqual(payload.layout.block.options.command, ["nvim"]);
	assert.equal(payload.layout.block.options.cwd, h.rexCalls[1].options.cwd);
	assert.ok(h.rexCalls.at(-1).args.includes("session.close_layer"));
});

test("Ctrl+Q keeps the existing inline Neovim outside Rex", async t => {
	const h = harness(t);
	await h.neovim();
	assert.equal(h.rexCalls.length, 0);
	assert.deepEqual(h.calls[0].args, ["-c", "nvim"]);
});

test("repeated Ctrl+Q does not open two Neovim instances", async t => {
	const h = harness(t, { rex: true });
	await Promise.all([h.neovim(), h.neovim()]);
	assert.equal(h.rexCalls.filter(call => call.args.includes("session.new_layer")).length, 1);
});

test("Neovim reports Rex errors and allows retry", async t => {
	const h = harness(t, { rex: true, rexFailure: true });
	await h.neovim();
	await h.neovim();
	assert.equal(h.notices.length, 2);
	assert.match(h.notices[0].message, /Neovim:.*Rex unavailable/);
	assert.equal(h.calls.length, 0);
});

test("both tuicr shortcuts use Rex floats", async t => {
	const h = harness(t, { rex: true, idle: false });
	await h.tuicr();
	await h.tuicr(true);
	assert.equal(h.calls.length, 0);
	const layers = h.rexCalls.filter(call => call.args.includes("session.new_layer"));
	assert.equal(layers.length, 2);
	assert.deepEqual(JSON.parse(layers[0].args.at(-1)).layout.block.options.command, ["tuicr", "--working-tree"]);
	assert.deepEqual(JSON.parse(layers[1].args.at(-1)).layout.block.options.command, ["tuicr", "pr", "42"]);
});

test("tuicr shortcuts preserve inline behavior outside Rex", async t => {
	const h = harness(t);
	await h.tuicr();
	await h.tuicr(true);
	assert.equal(h.rexCalls.length, 0);
	assert.deepEqual(h.calls.map(call => call.args), [
		["-c", "tuicr --working-tree"],
		["-c", 'tuicr pr "$(gh pr view --json number --jq .number)"'],
	]);
});

test("tuicr rejects failed PR lookup without opening a float", async t => {
	const h = harness(t, { rex: true, ghCode: 1 });
	await h.tuicr(true);
	assert.equal(h.rexCalls.length, 1);
	assert.match(h.notices[0].message, /No current PR/);
});

test("tuicr shortcuts share a duplicate-open guard", async t => {
	const h = harness(t, { rex: true });
	await Promise.all([h.tuicr(), h.tuicr(true)]);
	assert.equal(h.rexCalls.filter(call => call.args.includes("session.new_layer")).length, 1);
});

test("bang nvim and lazygit no longer receive automatic interactive handling", async t => {
	const h = harness(t);
	assert.equal(await h.bash("nvim"), undefined);
	assert.equal(await h.bash("nvim file.ts"), undefined);
	assert.equal(await h.bash("lazygit"), undefined);
	assert.equal(h.calls.length, 0);
});

test("repeated shortcuts do not open two LazyGit instances", async t => {
	const h = harness(t, { idle: false });
	await Promise.all([h.run(), h.run()]);
	assert.equal(h.calls.length, 1);
});
