import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function formatDuration(milliseconds: number): string {
	if (milliseconds < 1000) return `${Math.round(milliseconds)}ms`;
	if (milliseconds < 10_000) return `${(milliseconds / 1000).toFixed(1)}s`;
	if (milliseconds < 60_000) return `${Math.round(milliseconds / 1000)}s`;

	const minutes = Math.floor(milliseconds / 60_000);
	const seconds = Math.round((milliseconds % 60_000) / 1000);
	return `${minutes}m ${seconds}s`;
}

export default function (pi: ExtensionAPI) {
	let startedAt: number | undefined;

	pi.on("session_start", async (_event, ctx) => {
		startedAt = undefined;
		ctx.ui.setStatus("last-turn-time", undefined);
	});

	pi.on("agent_start", () => {
		startedAt = performance.now();
	});

	pi.on("agent_settled", async (_event, ctx) => {
		if (startedAt === undefined) return;

		const elapsed = performance.now() - startedAt;
		const theme = ctx.ui.theme;
		const label = theme.fg("text", "took ");
		const value = theme.fg("text", formatDuration(elapsed));
		ctx.ui.setStatus("last-turn-time", label + value);
		startedAt = undefined;
	});
}
