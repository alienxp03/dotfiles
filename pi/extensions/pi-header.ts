import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
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

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setHeader((_tui, theme) => ({
			render(width: number): string[] {
				const rows = DIGIT_ART.map((logo) =>
					truncateToWidth(theme.fg("accent", logo.trimEnd()), width, ""),
				);
				return ["", ...rows, ""];
			},
			invalidate() {},
		}));
	});
}
