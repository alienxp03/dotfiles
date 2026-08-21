import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Container, SelectList, Spacer, Text, type SelectItem } from "@earendil-works/pi-tui";

type ThinkingLevel = "medium" | "xhigh";

type ModelPreset = {
	label: string;
	provider: string;
	modelId: string;
	thinkingLevel: ThinkingLevel;
};

const PRESETS: ModelPreset[] = [
	{
		label: "Luna · xhigh",
		provider: "openai-codex",
		modelId: "gpt-5.6-luna",
		thinkingLevel: "xhigh",
	},
	{
		label: "Sol · medium",
		provider: "openai-codex",
		modelId: "gpt-5.6-sol",
		thinkingLevel: "medium",
	},
];

async function selectPreset(ctx: ExtensionContext): Promise<string | null> {
	const items: SelectItem[] = PRESETS.map((preset) => ({ value: preset.label, label: preset.label }));
	return (await ctx.ui.custom<string | null>(
		(tui, theme, _keybindings, done) => {
			const container = new Container();
			container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
			container.addChild(new Spacer(1));
			container.addChild(new Text(theme.fg("accent", theme.bold("Select model preset")), 3, 0));
			container.addChild(new Spacer(1));

			const selectList = new SelectList(items, items.length, {
				selectedPrefix: (text) => theme.fg("accent", text),
				selectedText: (text) => theme.fg("accent", text),
				description: (text) => theme.fg("muted", text),
				scrollInfo: (text) => theme.fg("dim", text),
				noMatch: (text) => theme.fg("warning", text),
			});
			selectList.onSelect = (item) => done(item.value);
			selectList.onCancel = () => done(null);
			container.addChild(selectList);
			container.addChild(new Spacer(1));
			container.addChild(new Text(theme.fg("dim", "↑↓/jk navigate • enter select • esc/q cancel"), 3, 0));
			container.addChild(new Spacer(1));
			container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));

			return {
				render: (width: number) => container.render(width),
				invalidate: () => container.invalidate(),
				handleInput: (data: string) => {
					if (data === "q") {
						done(null);
						return;
					}
					const mapped = data === "j" ? "\x1b[B" : data === "k" ? "\x1b[A" : data;
					selectList.handleInput(mapped);
					tui.requestRender();
				},
			};
		},
		{
			overlay: true,
			overlayOptions: {
				row: "40%",
				col: "50%",
				width: 46,
				maxHeight: 14,
			},
		},
	)) as string | null;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("reload-runtime", {
		description: "Reload Pi configuration",
		handler: async (_args, ctx) => {
			await ctx.reload();
			return;
		},
	});

	pi.registerShortcut("ctrl+r", {
		description: "Reload Pi configuration",
		handler: (ctx) => {
			const options = ctx.isIdle()
				? { expandPromptTemplates: true }
				: { deliverAs: "followUp" as const, expandPromptTemplates: true };
			pi.sendUserMessage("/reload-runtime", options);
		},
	});

	pi.registerShortcut("ctrl+shift+m", {
		description: "Select model preset",
		handler: async (ctx) => {
			const choice = await selectPreset(ctx);
			if (!choice) return;

			const preset = PRESETS.find((item) => item.label === choice);
			if (!preset) return;

			const model = ctx.modelRegistry.find(preset.provider, preset.modelId);
			if (!model) {
				ctx.ui.notify(`Model unavailable: ${preset.provider}/${preset.modelId}`, "error");
				return;
			}

			if (!(await pi.setModel(model))) {
				ctx.ui.notify(`No credentials available for ${preset.label}`, "error");
				return;
			}

			pi.setThinkingLevel(preset.thinkingLevel);
			ctx.ui.notify(`Using ${preset.label}`, "info");
		},
	});
}
