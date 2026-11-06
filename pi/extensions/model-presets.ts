import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

import { readFileSync, realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";

type ModelPreset = {
  label: string;
  provider: string;
  modelId: string;
  thinkingLevel: ThinkingLevel;
};

// Resolve the extension symlink so configs live alongside the dotfiles pi directory.
const CONFIG_DIR = dirname(dirname(realpathSync(fileURLToPath(import.meta.url))));
const THINKING_LEVELS = new Set(["off", "minimal", "low", "medium", "high", "xhigh", "max"]);

export function loadPresets(configDir = CONFIG_DIR): ModelPreset[] {
  let source = join(configDir, "model-presets.local.json");
  let contents: string;
  try {
    contents = readFileSync(source, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    source = join(configDir, "model-presets.json");
    contents = readFileSync(source, "utf8");
  }

  const presets: unknown = JSON.parse(contents);
  if (
    !Array.isArray(presets) ||
    presets.length === 0 ||
    !presets.every(
      (preset) =>
        preset !== null &&
        typeof preset === "object" &&
        ["label", "provider", "modelId"].every(
          (key) => typeof preset[key] === "string" && preset[key].trim().length > 0,
        ) &&
        THINKING_LEVELS.has(preset.thinkingLevel),
    )
  ) {
    throw new Error(`Invalid presets in ${source}: expected a non-empty array with label, provider, modelId, and thinkingLevel`);
  }
  return presets as ModelPreset[];
}

async function applyPreset(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  preset: ModelPreset,
): Promise<boolean> {
  const model = ctx.modelRegistry.find(preset.provider, preset.modelId);
  if (!model) {
    ctx.ui.notify(
      `Model unavailable: ${preset.provider}/${preset.modelId}`,
      "error",
    );
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
    handler: async (_args: any, ctx: { reload: () => any }) => {
      await ctx.reload();
      return;
    },
  });

  pi.registerShortcut("ctrl+r", {
    description: "Reload Pi configuration",
    handler: (ctx: { isIdle: () => any }) => {
      const options = ctx.isIdle()
        ? { expandPromptTemplates: true }
        : { deliverAs: "followUp" as const, expandPromptTemplates: true };
      pi.sendUserMessage("/reload-runtime", options);
    },
  });

  pi.registerShortcut("ctrl+shift+o", {
    description: "Rotate model preset",
    handler: async (ctx: any) => {
      let presets: ModelPreset[];
      try {
        presets = loadPresets();
      } catch (error) {
        ctx.ui.notify(`Could not load model presets: ${error instanceof Error ? error.message : String(error)}`, "error");
        return;
      }
      const nextPresetIndex = (activePresetIndex + 1) % presets.length;
      const preset = presets[nextPresetIndex];
      if (!(await applyPreset(pi, ctx, preset))) return;

      activePresetIndex = nextPresetIndex;
    },
  });
}
