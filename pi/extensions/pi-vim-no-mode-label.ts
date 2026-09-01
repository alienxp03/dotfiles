import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

type ModeLabelEditor = {
	getModeLabel?: () => string;
};

function wrapEditorWithoutInsertAndNormalLabels(ctx: ExtensionContext): void {
	const previous = ctx.ui.getEditorComponent();
	if (!previous) return;

	ctx.ui.setEditorComponent((tui, theme, keybindings) => {
		const editor = previous(tui, theme, keybindings);
		if (!editor) return editor;

		const modeLabelEditor = editor as unknown as ModeLabelEditor;
		if (typeof modeLabelEditor.getModeLabel !== "function") return editor;

		const getModeLabel = modeLabelEditor.getModeLabel.bind(editor);
		modeLabelEditor.getModeLabel = () => {
			const label = getModeLabel();
			return label.startsWith(" INSERT ") || label.startsWith(" NORMAL ")
				? ""
				: label;
		};

		return editor;
	});
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		const startedAt = Date.now();
		const timer = setInterval(() => {
			try {
				if (ctx.ui.getEditorComponent()) {
					clearInterval(timer);
					wrapEditorWithoutInsertAndNormalLabels(ctx);
					return;
				}
			} catch {
				// The session can be replaced while this short poll is still active.
				// Stop polling instead of using a stale extension context.
				clearInterval(timer);
				return;
			}

			// pi-vim is optional. Stop polling if it does not load shortly after
			// startup instead of keeping a timer alive for the whole session.
			if (Date.now() - startedAt > 5000) clearInterval(timer);
		}, 50);
		timer.unref?.();
	});
}
