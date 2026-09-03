import { randomUUID } from "node:crypto";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
	ReadonlySessionManager,
} from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

type Direction = "bottom" | "top" | "left" | "right";

const DIRECTIONS: Direction[] = ["bottom", "top", "left", "right"];
const DIRECTION_ALIASES: Record<string, Direction> = {
	b: "bottom",
	bottom: "bottom",
	t: "top",
	top: "top",
	l: "left",
	left: "left",
	r: "right",
	right: "right",
};

function parseDirection(args: string): Direction | undefined {
	const value = args.trim().split(/\s+/, 1)[0]?.toLowerCase() || "bottom";
	return DIRECTION_ALIASES[value];
}

function getKittyLocation(direction: Direction): "hsplit" | "vsplit" {
	return direction === "top" || direction === "bottom" ? "hsplit" : "vsplit";
}

function getDirectionCompletions(prefix: string): AutocompleteItem[] | null {
	const normalizedPrefix = prefix.toLowerCase();
	const items = DIRECTIONS.map((value) => ({ value, label: value }));
	const filtered = items.filter((item) => item.value.startsWith(normalizedPrefix));
	return filtered.length > 0 ? filtered : null;
}

function getCloneBranch(
	sessionManager: ReadonlySessionManager,
	running: boolean,
) {
	const entries = sessionManager.getBranch();
	if (!running) return entries;

	// When the parent is streaming, exclude the current user prompt and the
	// incomplete assistant response. Clone the conversation through the last
	// completed assistant reply instead.
	for (let index = entries.length - 1; index >= 0; index--) {
		const entry = entries[index];
		if (entry.type === "message" && entry.message.role === "assistant") {
			return entries.slice(0, index + 1);
		}
	}
	return [];
}

async function cloneCurrentConversation(
	sessionManager: ReadonlySessionManager,
	entries = sessionManager.getBranch(),
): Promise<string> {
	const cwd = sessionManager.getCwd();
	const sessionDir = sessionManager.getSessionDir();
	const id = randomUUID();
	const timestamp = new Date().toISOString();
	const fileTimestamp = timestamp.replace(/[:.]/g, "-");
	const sessionPath = join(sessionDir, `${fileTimestamp}_${id}.jsonl`);
	const header = {
		type: "session",
		version: sessionManager.getHeader().version ?? 3,
		id,
		timestamp,
		cwd,
		parentSession: sessionManager.getSessionFile(),
	};
	const content = [header, ...entries].map((entry) => JSON.stringify(entry)).join("\n") + "\n";

	await mkdir(sessionDir, { recursive: true });
	await writeFile(sessionPath, content, { encoding: "utf8", flag: "wx" });
	return sessionPath;
}

export default function (pi: ExtensionAPI) {
	const cloneHandler = async (args: string, ctx: ExtensionCommandContext) => {
		const direction = parseDirection(args);
		if (!direction) {
			ctx.ui.notify("Usage: /kclone [bottom|top|left|right]", "error");
			return;
		}
		if (!process.env.KITTY_WINDOW_ID) {
			ctx.ui.notify("/kclone requires Kitty", "error");
			return;
		}

		// Extension commands run immediately, even while the parent is streaming.
		// Snapshot the committed branch now; the live response is intentionally
		// not copied into the new pane.
		const running = !ctx.isIdle();
		const sessionPath = await cloneCurrentConversation(
			ctx.sessionManager,
			getCloneBranch(ctx.sessionManager, running),
		);
		const sourceWindowId = process.env.KITTY_WINDOW_ID;
		const launch = await pi.exec(
			"kitten",
			[
				"@",
				"launch",
				"--match",
				`window_id:${sourceWindowId}`,
				"--source-window",
				`id:${sourceWindowId}`,
				"--next-to",
				`id:${sourceWindowId}`,
				"--type=window",
				`--location=${getKittyLocation(direction)}`,
				"--bias=35",
				"--cwd",
				ctx.sessionManager.getCwd(),
				"--",
				"pi",
				"--session",
				sessionPath,
			],
			{ timeout: 5000 },
		);

		if (launch.code !== 0) {
			await rm(sessionPath, { force: true });
			ctx.ui.notify(`Could not open Kitty pane: ${launch.stderr.trim() || "remote control failed"}`, "error");
			return;
		}

		const windowId = launch.stdout.trim().split(/\s+/).at(-1);
		if ((direction === "top" || direction === "left") && windowId && /^\d+$/.test(windowId)) {
			const move = await pi.exec(
				"kitten",
				["@", "action", "--match", `id:${windowId}`, "move_window_backward"],
				{ timeout: 5000 },
			);
			if (move.code !== 0) {
				ctx.ui.notify(`Opened cloned conversation, but could not place it ${direction}: ${move.stderr.trim()}`, "warning");
				return;
			}
		}

		ctx.ui.notify(
			running
				? `Cloned conversation ${direction} (live response not included)`
				: `Cloned conversation ${direction}`,
			"info",
		);
	};

	const command = {
		description: "Clone the current conversation into an interactive Kitty pane",
		getArgumentCompletions: getDirectionCompletions,
		handler: cloneHandler,
	};
	pi.registerCommand("kclone", command);
}
