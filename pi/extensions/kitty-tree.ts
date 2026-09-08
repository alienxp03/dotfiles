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

type CloneResult = {
	placementError?: string;
};

type HerdrResponse = {
	error?: { message?: string };
	result?: { pane?: { pane_id?: string } };
};

function getHerdrDirection(direction: Direction): "right" | "down" {
	return direction === "left" || direction === "right" ? "right" : "down";
}

function getErrorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

async function runHerdr(
	pi: ExtensionAPI,
	args: string[],
	timeout: number,
): Promise<HerdrResponse> {
	const result = await pi.exec("herdr", args, { timeout });
	const output = result.stderr.trim() || result.stdout.trim();

	if (result.code !== 0) {
		let message = output;
		try {
			message = JSON.parse(output).error?.message || output;
		} catch {
			// Keep the raw CLI error when it is not JSON.
		}
		throw new Error(message || "Herdr API request failed");
	}

	try {
		const response = JSON.parse(result.stdout) as HerdrResponse;
		if (response.error?.message) throw new Error(response.error.message);
		return response;
	} catch (error) {
		if (error instanceof Error && error.message !== "Unexpected end of JSON input") {
			throw error;
		}
		throw new Error("Herdr returned an invalid response");
	}
}

function getCreatedPaneId(response: HerdrResponse): string {
	const paneId = response.result?.pane?.pane_id;
	if (!paneId) throw new Error("Herdr did not return the new pane ID");
	return paneId;
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

async function cloneInKitty(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	direction: Direction,
	sessionPath: string,
): Promise<CloneResult> {
	const sourceWindowId = process.env.KITTY_WINDOW_ID;
	if (!sourceWindowId) throw new Error("KITTY_WINDOW_ID is not set");

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
		throw new Error(launch.stderr.trim() || "remote control failed");
	}

	const windowId = launch.stdout.trim().split(/\s+/).at(-1);
	if ((direction === "top" || direction === "left") && windowId && /^\d+$/.test(windowId)) {
		const move = await pi.exec(
			"kitten",
			["@", "action", "--match", `id:${windowId}`, "move_window_backward"],
			{ timeout: 5000 },
		);
		if (move.code !== 0) {
			return {
				placementError: move.stderr.trim() || "remote control failed",
			};
		}
	}

	return {};
}

async function cloneInHerdr(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	direction: Direction,
	sessionPath: string,
): Promise<CloneResult> {
	const sourcePaneId = process.env.HERDR_PANE_ID;
	if (!sourcePaneId) throw new Error("HERDR_PANE_ID is not set");

	const split = await runHerdr(
		pi,
		[
			"pane",
			"split",
			"--pane",
			sourcePaneId,
			"--direction",
			getHerdrDirection(direction),
			// Herdr's ratio is the existing pane's share; Kitty's bias is the new pane's share.
			"--ratio",
			"0.65",
			"--focus",
			"--cwd",
			ctx.sessionManager.getCwd(),
		],
		5000,
	);
	const paneId = getCreatedPaneId(split);
	const agentName = `clone-${randomUUID().slice(0, 8)}`;

	await runHerdr(
		pi,
		[
			"agent",
			"start",
			agentName,
			"--kind",
			"pi",
			"--pane",
			paneId,
			"--timeout",
			"30000",
			"--",
			"--session",
			sessionPath,
		],
		35000,
	);

	if (direction === "top" || direction === "left") {
		try {
			await runHerdr(
				pi,
				[
					"pane",
					"swap",
					"--source-pane",
					paneId,
					"--target-pane",
					sourcePaneId,
				],
				5000,
			);
		} catch (error) {
			return { placementError: getErrorMessage(error) };
		}
	}

	return {};
}

export default function (pi: ExtensionAPI) {
	const cloneHandler = async (args: string, ctx: ExtensionCommandContext) => {
		const direction = parseDirection(args);
		if (!direction) {
			ctx.ui.notify("Usage: /kclone [bottom|top|left|right]", "error");
			return;
		}

		const herdr = process.env.HERDR_ENV === "1";
		if (herdr && !process.env.HERDR_PANE_ID) {
			ctx.ui.notify("/kclone could not find the current Herdr pane", "error");
			return;
		}
		if (!herdr && !process.env.KITTY_WINDOW_ID) {
			ctx.ui.notify("/kclone requires Kitty or Herdr", "error");
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

		let cloneResult: CloneResult;
		try {
			cloneResult = herdr
				? await cloneInHerdr(pi, ctx, direction, sessionPath)
				: await cloneInKitty(pi, ctx, direction, sessionPath);
		} catch (error) {
			// Herdr may leave a pane running when agent startup times out.
			// Keep its session file available in that case.
			if (!herdr) await rm(sessionPath, { force: true });
			ctx.ui.notify(
				`Could not open ${herdr ? "Herdr" : "Kitty"} pane: ${getErrorMessage(error)}`,
				"error",
			);
			return;
		}

		if (cloneResult.placementError) {
			ctx.ui.notify(
				`Opened cloned conversation, but could not place it ${direction}: ${cloneResult.placementError}`,
				"warning",
			);
			return;
		}

		ctx.ui.notify(
			running
				? `Cloned conversation ${direction} (live response not included)`
				: `Cloned conversation ${direction}`,
			"info",
		);
	};

	const command = {
		description: "Clone the current conversation into a Kitty or Herdr pane",
		getArgumentCompletions: getDirectionCompletions,
		handler: cloneHandler,
	};
	pi.registerCommand("kclone", command);
}
