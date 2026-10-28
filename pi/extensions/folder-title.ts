import { basename } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;
	let updateTitle: (() => void) | undefined;
	let prefix = "";
	const symbols = { working: "ϟ", blocked: "?", done: "✓", error: "×", idle: "", clear: "" };

	pi.events.on("rex:status", (event: unknown) => {
		if (!event || typeof event !== "object") return;
		const state = (event as { state?: unknown }).state;
		if (typeof state !== "string" || !Object.hasOwn(symbols, state)) return;
		prefix = symbols[state as keyof typeof symbols];
		updateTitle?.();
	});

	function stop() {
		if (timer) clearInterval(timer);
		timer = undefined;
		updateTitle = undefined;
		prefix = "";
	}

	pi.on("session_start", (_event, ctx) => {
		stop();
		if (ctx.mode !== "tui") return;

		const update = () => {
			const folder = basename(ctx.cwd) || ctx.cwd;
			ctx.ui.setTitle(prefix ? `${prefix} ${folder}` : folder);
		};
		updateTitle = update;
		update();
		// Pi resets its title after startup, reload, and session-name changes.
		timer = setInterval(update, 1000);
		timer.unref();
	});

	pi.on("session_shutdown", stop);
}
