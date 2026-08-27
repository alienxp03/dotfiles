import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ResumePrefixState = {
	active: boolean;
	write: typeof process.stdout.write;
};

const STATE_KEY = "__pi_remove_resume_prefix_state__";
const globalState = globalThis as typeof globalThis & Record<string, ResumePrefixState | undefined>;

// Pi writes this hint directly during shutdown; keep the rewrite scoped to that output.
let state = globalState[STATE_KEY];
if (!state) {
	state = {
		active: false,
		write: process.stdout.write.bind(process.stdout),
	};
	globalState[STATE_KEY] = state;

	const originalWrite = state.write;
	process.stdout.write = ((chunk: string | Uint8Array, ...args: any[]) => {
		if (state?.active && typeof chunk === "string") {
			chunk = chunk.replace(
				/(?:\u001b\[[0-9;]*m)?To resume this session:(?:\u001b\[[0-9;]*m)? ?/g,
				"",
			);
		}
		return originalWrite(chunk, ...args);
	}) as typeof process.stdout.write;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", () => {
		state!.active = false;
	});

	pi.on("session_shutdown", (event) => {
		state!.active = event.reason === "quit";
	});
}
