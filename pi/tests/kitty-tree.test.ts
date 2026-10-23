import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { resolve } from "node:path";
import { test } from "node:test";
import install from "../extensions/kitty-tree.ts";

async function harness(t, { idle = true, code = 0 } = {}) {
	const directory = await mkdtemp(resolve("aux/kclone-"));
	const keys = ["CMUX_WORKSPACE_ID", "CMUX_SURFACE_ID", "CMUX_PI_CMUX_BIN", "CMUX_BUNDLED_CLI_PATH", "HERDR_ENV", "KITTY_WINDOW_ID"];
	const saved = keys.map(key => process.env[key]);
	for (const key of keys) delete process.env[key];
	Object.assign(process.env, {
		CMUX_WORKSPACE_ID: "workspace-test",
		CMUX_SURFACE_ID: "surface-test",
		CMUX_BUNDLED_CLI_PATH: "/test/cmux",
		KITTY_WINDOW_ID: "123",
	});
	t.after(async () => {
		keys.forEach((key, index) => {
			if (saved[index] === undefined) delete process.env[key];
			else process.env[key] = saved[index];
		});
		await rm(directory, { recursive: true, force: true });
	});
	const calls = [];
	const notices = [];
	const commands = new Map();
	const entries = [
		{ type: "message", id: "a", message: { role: "assistant", content: "Done" } },
		{ type: "message", id: "b", message: { role: "user", content: "Next" } },
	];
	install({
		registerCommand: (name, command) => commands.set(name, command),
		exec: async (command, args, options) => {
			calls.push({ command, args, options });
			return { code, stdout: "", stderr: code ? "split failed" : "" };
		},
	});
	const ctx = {
		isIdle: () => idle,
		ui: { notify: (text, level) => notices.push({ text, level }) },
		sessionManager: {
			getCwd: () => "/test/it's a project",
			getSessionDir: () => directory,
			getHeader: () => ({ version: 3 }),
			getSessionFile: () => "/parent.jsonl",
			getBranch: () => entries,
		},
	};
	return { calls, notices, entries, run: args => commands.get("kclone").handler(args, ctx) };
}

for (const [input, direction] of [["", "down"], ["top", "up"], ["left", "left"], ["r", "right"]]) {
	test(`cmux clones ${input || "bottom"} from the caller surface`, async t => {
		const h = await harness(t);
		await h.run(input);
		assert.equal(h.calls.length, 1);
		const call = h.calls[0];
		assert.equal(call.command, "/test/cmux");
		assert.deepEqual(call.args.slice(0, 6), ["new-split", direction, "--workspace", "workspace-test", "--surface", "surface-test"]);
		assert.deepEqual(call.args.slice(-2), ["--focus", "true"]);
		assert.ok(call.args[7].startsWith(`cd -- '/test/it'"'"'s a project' && pi --session '`));
		const path = call.args[7].split(" && pi --session '")[1].slice(0, -1);
		const [header, ...entries] = (await readFile(path, "utf8")).trim().split("\n").map(line => JSON.parse(line));
		assert.equal(header.parentSession, "/parent.jsonl");
		assert.deepEqual(entries, h.entries);
		assert.equal(h.notices.at(-1).level, "info");
	});
}

test("cmux excludes the live prompt when busy", async t => {
	const h = await harness(t, { idle: false });
	await h.run("bottom");
	const path = h.calls[0].args[7].split(" && pi --session '")[1].slice(0, -1);
	const entries = (await readFile(path, "utf8")).trim().split("\n").slice(1).map(line => JSON.parse(line));
	assert.deepEqual(entries, h.entries.slice(0, 1));
	assert.match(h.notices.at(-1).text, /live response not included/);
});

test("cmux rejects a missing surface before making a snapshot", async t => {
	const h = await harness(t);
	delete process.env.CMUX_SURFACE_ID;
	await h.run("");
	assert.equal(h.calls.length, 0);
	assert.equal(h.notices.at(-1).level, "error");
});

test("cmux reports split errors and keeps the snapshot", async t => {
	const h = await harness(t, { code: 1 });
	await h.run("");
	assert.equal(h.notices.at(-1).text, "Could not open cmux pane: split failed");
	const path = h.calls[0].args[7].split(" && pi --session '")[1].slice(0, -1);
	assert.ok(await readFile(path, "utf8"));
});
