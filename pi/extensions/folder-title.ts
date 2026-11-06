import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;

	function stop() {
		if (timer) clearInterval(timer);
		timer = undefined;
	}

	function update(ctx: ExtensionContext) {
		if (ctx.mode !== "tui") return;
		const folder = basename(ctx.cwd) || ctx.cwd;
		const name = ctx.sessionManager.getSessionName();
		ctx.ui.setTitle(name ? `${folder} — ${name}` : folder);
	}

	pi.on("session_start", (_event, ctx) => {
		stop();
		if (ctx.mode !== "tui") return;

		update(ctx);
		// Pi resets its title after startup, reload, and session-name changes.
		timer = setInterval(() => update(ctx), 1000);
		timer.unref();
	});

	pi.on("session_info_changed", (_event, ctx) => update(ctx));
	pi.on("session_shutdown", stop);
}
