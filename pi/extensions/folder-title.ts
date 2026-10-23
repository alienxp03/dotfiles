import { basename } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;

	function stop() {
		if (timer) clearInterval(timer);
		timer = undefined;
	}

	pi.on("session_start", (_event, ctx) => {
		stop();
		if (ctx.mode !== "tui") return;

		const update = () => ctx.ui.setTitle(basename(ctx.cwd) || ctx.cwd);
		update();
		// Pi resets its title after startup, reload, and session-name changes.
		timer = setInterval(update, 1000);
		timer.unref();
	});

	pi.on("session_shutdown", stop);
}
