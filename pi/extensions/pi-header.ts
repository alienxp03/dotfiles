import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const PI_DIGITS =
	"31415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679821480865132823066470938446095505822317253594081284811174502841027019385211055596446229489549303819644288109756659334461284756482337867831652712019091456485669";

const LOGO_MASK = [
	"⠀⠀⠀⠀⢀⣠⣤⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣦⠀",
	"⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃",
	"⠀⣴⣿⣿⣿⣿⣿⠿⢿⣿⣿⣿⣿⡟⠛⠛⠛⣿⣿⣿⣿⣿⠛⠛⠛⠛⠛⠛⠁⠀",
	"⠘⣿⣿⣿⣿⠟⠁⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠉⠛⠛⠁⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡿⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⡇⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⣿⠁⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⢀⣤⣤⡀⠀",
	"⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⢠⣿⣿⣿⣿⡄",
	"⠀⠀⠀⠀⢠⣾⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣤⣤⣾⣿⣿⣿⣿⠁",
	"⠀⠀⠀⢰⣿⣿⣿⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠘⢿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠀",
	"⠀⠀⠀⠀⠻⠿⠿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⠿⠿⠿⠿⠟⠋⠀⠀⠀",
];

const DIGIT_ART = (() => {
	let digitIndex = 0;
	return LOGO_MASK.map((line) =>
		[...line]
			.map((cell) => {
				if (cell === "⠀" || cell === " ") return " ";
				return PI_DIGITS[digitIndex++ % PI_DIGITS.length];
			})
			.join(""),
	);
})();

const LOGO_WIDTH = Math.max(...DIGIT_ART.map((line) => line.length));
const PANEL_GAP = 7;
const STARFIELD_WIDTH = 34;
const STARFIELD_HEIGHT = DIGIT_ART.length;
const STARS = [
	[7, 0, "·"],
	[19, 0, "⋆"],
	[30, 1, "·"],
	[2, 2, "⋆"],
	[13, 3, "·"],
	[25, 3, "⋆"],
	[6, 5, "·"],
	[31, 5, "·"],
	[16, 6, "⋆"],
	[1, 8, "·"],
	[10, 9, "⋆"],
	[27, 9, "·"],
	[19, 11, "·"],
	[32, 12, "⋆"],
] as const;

function renderStarfield(frame: number, theme: Theme): string[] {
	const canvas = Array.from({ length: STARFIELD_HEIGHT }, () =>
		Array.from({ length: STARFIELD_WIDTH }, () => " "),
	);

	for (const [index, [x, y, glyph]] of STARS.entries()) {
		canvas[y]![x] =
			index === frame % STARS.length
				? theme.fg("accent", "✦")
				: theme.fg("dim", glyph);
	}
	canvas[6]![26] = theme.fg("muted", "☾");

	return canvas.map((row) => row.join("").trimEnd());
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setHeader((tui, theme) => {
			let frame = 0;
			const timer = setInterval(() => {
				frame = (frame + 1) % STARS.length;
				tui.requestRender();
			}, 700);
			timer.unref?.();

			return {
				render(width: number): string[] {
					const showStarfield =
						width >= LOGO_WIDTH + PANEL_GAP + STARFIELD_WIDTH;
					const starfield = showStarfield ? renderStarfield(frame, theme) : [];
					const rows = DIGIT_ART.map((logo, index) => {
						const styledLogo = theme.fg("accent", logo.trimEnd());
						if (!showStarfield)
							return truncateToWidth(styledLogo, width, "");

						const gap = " ".repeat(
							LOGO_WIDTH - logo.trimEnd().length + PANEL_GAP,
						);
						return truncateToWidth(
							`${styledLogo}${gap}${starfield[index] ?? ""}`,
							width,
							"",
						);
					});
					return ["", ...rows, ""];
				},
				invalidate() {},
				dispose() {
					clearInterval(timer);
				},
			};
		});
	});
}
