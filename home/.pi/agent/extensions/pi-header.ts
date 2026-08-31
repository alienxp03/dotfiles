import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DOT_ART = [
	"⠀⠀⢠⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⡄⠀⠀",
	"⠀⠀⠈⢹⣿⠉⠉⠉⠉⠉⠉⣿⡏⠁⠀⠀",
	"⠀⠀⠀⢸⣿⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀",
	"⠀⠀⠀⢸⣿⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀",
	"⠀⠀⠀⢸⣿⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀",
];

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setHeader((_tui, theme) => ({
			render(_width: number): string[] {
				return [
					"",
					...DOT_ART.map((line) => theme.fg("accent", line)),
					"",
				];
			},
			invalidate() {},
		}));
	});
}
