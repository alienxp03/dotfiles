import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type ThinkingLevel = "high" | "xhigh";

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
		label: "Sol · high",
		provider: "openai-codex",
		modelId: "gpt-5.6-sol",
		thinkingLevel: "high",
	},
];

async function applyPreset(pi: ExtensionAPI, ctx: ExtensionContext, preset: ModelPreset): Promise<boolean> {
	const model = ctx.modelRegistry.find(preset.provider, preset.modelId);
	if (!model) {
		ctx.ui.notify(`Model unavailable: ${preset.provider}/${preset.modelId}`, "error");
		return false;
	}

	if (!(await pi.setModel(model))) {
		ctx.ui.notify(`No credentials available for ${preset.label}`, "error");
		return false;
	}

	pi.setThinkingLevel(preset.thinkingLevel);
	ctx.ui.notify(`Using ${preset.label}`, "info");
	return true;
}

export default function (pi: ExtensionAPI) {
	let activePresetIndex = 0;

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

	pi.registerShortcut("ctrl+shift+o", {
		description: "Rotate model preset",
		handler: async (ctx) => {
			const nextPresetIndex = (activePresetIndex + 1) % PRESETS.length;
			const preset = PRESETS[nextPresetIndex];
			if (!(await applyPreset(pi, ctx, preset))) return;

			activePresetIndex = nextPresetIndex;
		},
	});
}
