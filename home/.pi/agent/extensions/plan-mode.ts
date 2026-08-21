import { mkdirSync, readdirSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type Mode = "default" | "plan";

type SavedState = {
	mode?: Mode;
	toolsBeforePlan?: string[];
};

const PLAN_DISABLED_TOOLS = new Set(["edit", "write"]);
const READONLY_BASH_PREFIXES = [
	"git status",
	"git diff",
	"git log",
	"git show",
	"git branch",
	"git ls-files",
	"git rev-parse",
	"git remote",
	"ls",
	"pwd",
	"find",
	"grep",
	"rg",
	"cat",
	"head",
	"tail",
	"sed -n",
	"wc",
	"file",
	"which",
	"type",
];

const PLAN_PROMPT = `

[PLAN MODE ACTIVE]
You are in read-only planning mode. Investigate the repository thoroughly, but do not modify files or run commands that change state.

Produce a self-contained implementation plan as your final response. Use this structure:
# <short plan title>
## Context
## Files to Read
## Files to Modify
## Files to Create
## Plan
1. Concrete implementation step
2. Concrete implementation step
## Risks
## Testing Strategy
## Done When

Ask clarifying questions if the requirements are ambiguous. Do not use edit or write; they are disabled in this mode.`;

type AssistantLike = {
	role: string;
	content: readonly unknown[];
};

type TextBlock = {
	type: "text";
	text: string;
};

function isAssistantMessage(message: unknown): message is AssistantLike {
	if (typeof message !== "object" || message === null) return false;
	const candidate = message as { role?: unknown; content?: unknown };
	return candidate.role === "assistant" && Array.isArray(candidate.content);
}

function getTextContent(message: AssistantLike): string {
	return message.content
		.filter((block): block is TextBlock => {
			if (typeof block !== "object" || block === null) return false;
			const candidate = block as { type?: unknown; text?: unknown };
			return candidate.type === "text" && typeof candidate.text === "string";
		})
		.map((block) => block.text)
		.join("\n");
}

function isReadonlyBash(command: string): boolean {
	const normalized = command.trim();
	if (!normalized || /[;&|><`]/.test(normalized)) return false;

	const withoutEnv = normalized.replace(/^(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)+/, "");
	return READONLY_BASH_PREFIXES.some(
		(prefix) => withoutEnv === prefix || withoutEnv.startsWith(`${prefix} `),
	);
}

function planFilename(planText: string): string {
	const title = planText.match(/^#\s+(.+)$/m)?.[1] ?? "plan";
	const slug = title
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 64);
	const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
	return `${slug || "plan"}-${timestamp}.md`;
}


function readSavedState(ctx: ExtensionContext): SavedState {
	const entries = ctx.sessionManager.getEntries();
	for (let index = entries.length - 1; index >= 0; index--) {
		const entry = entries[index] as {
			type?: string;
			customType?: string;
			data?: SavedState;
		};
		if (entry.type === "custom" && entry.customType === "plan-mode" && entry.data) {
			return entry.data;
		}
	}
	return { mode: "default" };
}

export default function planModeExtension(pi: ExtensionAPI): void {
	let mode: Mode = "default";
	let toolsBeforePlan: string[] | undefined;

	pi.registerFlag("plan", {
		description: "Start in plan mode (read-only exploration)",
		type: "boolean",
		default: false,
	});

	function persist(): void {
		pi.appendEntry("plan-mode", { mode, toolsBeforePlan });
	}

	function updateStatus(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		ctx.ui.setStatus("plan-mode", mode === "plan" ? ctx.ui.theme.fg("accent", "∥∥ PLAN") : undefined);
	}

	function setMode(nextMode: Mode, ctx: ExtensionContext, shouldPersist = true): void {
		if (nextMode === mode && (nextMode !== "plan" || toolsBeforePlan)) return;

		if (nextMode === "plan") {
			if (!toolsBeforePlan) toolsBeforePlan = pi.getActiveTools();
			pi.setActiveTools(toolsBeforePlan.filter((tool) => !PLAN_DISABLED_TOOLS.has(tool)));
		} else {
			pi.setActiveTools(toolsBeforePlan ?? pi.getActiveTools());
			toolsBeforePlan = undefined;
		}

		mode = nextMode;
		if (shouldPersist) persist();
		updateStatus(ctx);
		if (ctx.hasUI) {
			ctx.ui.notify(
				mode === "plan"
					? "Plan mode enabled — edits and mutating commands are blocked."
					: "Full tool access.",
				"info",
			);
		}
	}

	pi.registerShortcut("shift+tab", {
		description: "Toggle plan mode",
		handler: async (ctx) => {
			const nextMode: Mode = mode === "plan" ? "default" : "plan";
			setMode(nextMode, ctx);
		},
	});

	pi.registerCommand("plan", {
		description: "Toggle plan mode; use /plan on or /plan off",
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase();
			const nextMode: Mode = requested === "on" ? "plan" : requested === "off" ? "default" : mode === "plan" ? "default" : "plan";
			setMode(nextMode, ctx);
		},
	});

	pi.on("before_agent_start", async (event) => {
		if (mode !== "plan") return;
		return { systemPrompt: event.systemPrompt + PLAN_PROMPT };
	});

	pi.on("tool_call", async (event) => {
		if (mode !== "plan") return;

		if (PLAN_DISABLED_TOOLS.has(event.toolName)) {
			return {
				block: true,
				reason: `[PLAN MODE] ${event.toolName} is disabled. Describe the change in the plan instead.`,
			};
		}

		if (event.toolName === "bash") {
			const command = (event.input as { command?: string }).command ?? "";
			if (!isReadonlyBash(command)) {
				return {
					block: true,
					reason: "[PLAN MODE] Only allowlisted read-only Bash commands are allowed.",
				};
			}
		}
	});

	pi.on("agent_end", async (event, ctx) => {
		if (mode !== "plan" || !ctx.hasUI) return;

		const lastAssistant = [...event.messages].reverse().find(isAssistantMessage);
		if (!lastAssistant) return;

		const planText = getTextContent(lastAssistant).trim();
		if (!/^##?\s*(?:implementation )?plan\b/im.test(planText)) return;

		const plansDir = join(ctx.cwd, ".pi", "plans");
		const filepath = join(plansDir, planFilename(planText));
		mkdirSync(plansDir, { recursive: true });
		writeFileSync(
			filepath,
			`---\ncreated: ${new Date().toISOString()}\nmode: plan\n---\n\n${planText}\n`,
			"utf8",
		);
		ctx.ui.notify(`Plan saved to ${relative(ctx.cwd, filepath)}`, "success");
	});

	pi.registerCommand("plans", {
		description: "List saved implementation plans",
		handler: async (_args, ctx) => {
			const plansDir = join(ctx.cwd, ".pi", "plans");
			let plans: string[] = [];
			try {
				plans = readdirSync(plansDir).filter((file) => file.endsWith(".md")).sort().reverse();
			} catch {
				// The directory is created when the first plan is saved.
			}
			ctx.ui.notify(
				plans.length > 0 ? `Saved plans:\n${plans.join("\n")}` : "No saved plans in .pi/plans/.",
				"info",
			);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		const saved = readSavedState(ctx);
		mode = pi.getFlag("plan") === true ? "plan" : saved.mode ?? "default";
		toolsBeforePlan = saved.toolsBeforePlan;

		if (mode === "plan") {
			if (!toolsBeforePlan) toolsBeforePlan = pi.getActiveTools();
			pi.setActiveTools(toolsBeforePlan.filter((tool) => !PLAN_DISABLED_TOOLS.has(tool)));
		}
		updateStatus(ctx);
	});
}
