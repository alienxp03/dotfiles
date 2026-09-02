import {
	estimateTokens,
	sessionEntryToContextMessages,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
	truncateToWidth,
	visibleWidth,
	type Component,
	type KeybindingsManager,
	type TUI,
} from "@earendil-works/pi-tui";

function estimateTextTokens(text: string): number {
	return Math.ceil(text.length / 4);
}

function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function textSection(source: string, startMarker: string, endMarker: string): string {
	const start = source.indexOf(startMarker);
	if (start < 0) return "";

	const end = source.indexOf(endMarker, start + startMarker.length);
	return end < 0 ? source.slice(start) : source.slice(start, end + endMarker.length);
}

function skillSection(source: string): string {
	return textSection(
		source,
		"The following skills provide specialized instructions for specific tasks.",
		"</available_skills>",
	);
}

function decodeXml(text: string): string {
	return text
		.replaceAll("&lt;", "<")
		.replaceAll("&gt;", ">")
		.replaceAll("&quot;", '"')
		.replaceAll("&apos;", "'")
		.replaceAll("&amp;", "&");
}

type ToolInfo = ReturnType<ExtensionAPI["getAllTools"]>[number];
type ContextMessage = ReturnType<typeof sessionEntryToContextMessages>[number];

type ReportItem = {
	id: string;
	label: string;
	tokens: number;
	children: ReportItem[];
};

type Breakdown = {
	categories: ReportItem[];
	estimatedTotal: number;
	reportedTotal?: number;
	contextWindow: number;
};

type DisplayRow = {
	item: ReportItem;
	depth: number;
	percentOf: number;
};

function estimateToolTokens(tools: ToolInfo[]): number {
	if (tools.length === 0) return 0;

	const serialized = tools.map((tool) => ({
		name: tool.name,
		description: tool.description,
		parameters: tool.parameters,
	}));
	return estimateTextTokens(JSON.stringify(serialized));
}

function fitChildren(children: ReportItem[], total: number, id: string): ReportItem[] {
	const normalized = children.map((child) => ({ ...child }));
	let difference = total - normalized.reduce((sum, child) => sum + child.tokens, 0);

	if (difference > 0) {
		normalized.push({
			id: `${id}:formatting`,
			label: "Formatting overhead",
			tokens: difference,
			children: [],
		});
	} else if (difference < 0) {
		for (let index = normalized.length - 1; index >= 0 && difference < 0; index--) {
			const child = normalized[index]!;
			const reduction = Math.min(child.tokens, -difference);
			child.tokens -= reduction;
			difference += reduction;
		}
	}

	return normalized.filter((child) => child.tokens > 0);
}

function parseContextFileItems(source: string, total: number): ReportItem[] {
	const children: ReportItem[] = [];
	const pattern = /<project_instructions path="([^"]+)">[\s\S]*?<\/project_instructions>/g;
	let match: RegExpExecArray | null;
	while ((match = pattern.exec(source)) !== null) {
		children.push({
			id: `context:${match[1]}`,
			label: match[1]!,
			tokens: estimateTextTokens(match[0]),
			children: [],
		});
	}
	return fitChildren(children, total, "context");
}

function parseSkillItems(source: string, total: number): ReportItem[] {
	const children: ReportItem[] = [];
	const pattern = /<skill>[\s\S]*?<name>([\s\S]*?)<\/name>[\s\S]*?<\/skill>/g;
	let match: RegExpExecArray | null;
	while ((match = pattern.exec(source)) !== null) {
		children.push({
			id: `skill:${match[1]}`,
			label: decodeXml(match[1]!.trim()),
			tokens: estimateTextTokens(match[0]),
			children: [],
		});
	}
	return fitChildren(children, total, "skills");
}

function messageLabel(message: ContextMessage, index: number): string {
	const toolName = "toolName" in message && typeof message.toolName === "string" ? `:${message.toolName}` : "";
	return `${message.role}${toolName} #${index}`;
}

function getReportedContextTokens(ctx: ExtensionContext): number | undefined {
	const hasUsableAssistantUsage = ctx.sessionManager.getBranch().some((entry) => {
		if (entry.type !== "message" || entry.message.role !== "assistant") return false;
		if (entry.message.stopReason === "aborted" || entry.message.stopReason === "error") return false;

		const usage = entry.message.usage;
		return (
			(usage.totalTokens ??
				usage.input + usage.output + usage.cacheRead + usage.cacheWrite) > 0
		);
	});
	if (!hasUsableAssistantUsage) return undefined;

	const usage = ctx.getContextUsage();
	return usage?.tokens ?? undefined;
}

function calculateBreakdown(pi: ExtensionAPI, ctx: ExtensionContext): Breakdown {
	const systemPrompt = ctx.getSystemPrompt();
	const contextText = textSection(systemPrompt, "<project_context>", "</project_context>");
	const skillsText = skillSection(systemPrompt);
	const systemPromptTokens = estimateTextTokens(systemPrompt);
	const contextTokens = estimateTextTokens(contextText);
	const skillsTokens = estimateTextTokens(skillsText);

	const activeTools = new Set(pi.getActiveTools());
	const tools = pi.getAllTools().filter((tool) => activeTools.has(tool.name));
	const systemTools = tools.filter((tool) => tool.sourceInfo.source === "builtin");
	const extensionTools = tools.filter((tool) => tool.sourceInfo.source !== "builtin");

	const messages: ReportItem[] = [];
	let messageIndex = 0;
	for (const entry of ctx.sessionManager.buildContextEntries()) {
		for (const message of sessionEntryToContextMessages(entry)) {
			messageIndex++;
			messages.push({
				id: `message:${messageIndex}`,
				label: messageLabel(message, messageIndex),
				tokens: estimateTokens(message),
				children: [],
			});
		}
	}

	const categories: ReportItem[] = [
		{
			id: "system-prompt",
			label: "System prompt",
			tokens: Math.max(0, systemPromptTokens - contextTokens - skillsTokens),
			children: [
				{
					id: "system-prompt:base",
					label: "Base instructions, guidelines, and working directory",
					tokens: Math.max(0, systemPromptTokens - contextTokens - skillsTokens),
					children: [],
				},
			],
		},
		{
			id: "context-files",
			label: "Context files",
			tokens: contextTokens,
			children: parseContextFileItems(contextText, contextTokens),
		},
		{
			id: "skills",
			label: "Skill index",
			tokens: skillsTokens,
			children: parseSkillItems(skillsText, skillsTokens),
		},
		{
			id: "system-tools",
			label: "System tools",
			tokens: estimateToolTokens(systemTools),
			children: fitChildren(
				systemTools.map((tool) => ({
					id: `system-tool:${tool.name}`,
					label: tool.name,
					tokens: estimateToolTokens([tool]),
					children: [],
				})),
				estimateToolTokens(systemTools),
				"system-tools",
			),
		},
		{
			id: "extension-tools",
			label: "Extension tools",
			tokens: estimateToolTokens(extensionTools),
			children: fitChildren(
				extensionTools.map((tool) => ({
					id: `extension-tool:${tool.name}`,
					label: tool.name,
					tokens: estimateToolTokens([tool]),
					children: [],
				})),
				estimateToolTokens(extensionTools),
				"extension-tools",
			),
		},
		{
			id: "messages",
			label: "Messages",
			tokens: messages.reduce((sum, message) => sum + message.tokens, 0),
			children: messages,
		},
	];

	const estimatedTotal = categories.reduce((sum, category) => sum + category.tokens, 0);
	return {
		categories: categories.sort((a, b) => b.tokens - a.tokens),
		estimatedTotal,
		reportedTotal: getReportedContextTokens(ctx),
		contextWindow: ctx.model?.contextWindow ?? 0,
	};
}

function flattenRows(
	items: ReportItem[],
	expanded: Set<string>,
	rows: DisplayRow[],
	depth: number,
	percentOf: number,
): void {
	for (const item of items) {
		rows.push({ item, depth, percentOf });
		if (item.children.length > 0 && expanded.has(item.id)) {
			flattenRows(item.children, expanded, rows, depth + 1, item.tokens);
		}
	}
}

function padLine(text: string, width: number): string {
	const truncated = truncateToWidth(text, width, "");
	return truncated + " ".repeat(Math.max(0, width - visibleWidth(truncated)));
}

class ContextUsageOverlay implements Component {
	private readonly expanded = new Set<string>();
	private rows: DisplayRow[] = [];
	private selectedIndex = 0;
	private scrollTop = 0;

	constructor(
		private readonly pi: ExtensionAPI,
		private readonly ctx: ExtensionContext,
		private readonly tui: TUI,
		private readonly theme: ExtensionContext["ui"]["theme"],
		private readonly keybindings: KeybindingsManager,
		private readonly done: () => void,
	) {}

	invalidate(): void {}

	private maxBodyRows(): number {
		return Math.max(4, Math.floor(this.tui.terminal.rows * 0.8) - 8);
	}

	private rebuildRows(report: Breakdown): void {
		this.rows = [];
		flattenRows(report.categories, this.expanded, this.rows, 0, report.contextWindow);
		if (this.rows.length === 0) {
			this.selectedIndex = 0;
			this.scrollTop = 0;
			return;
		}
		this.selectedIndex = Math.min(this.selectedIndex, this.rows.length - 1);
		const maxScrollTop = Math.max(0, this.rows.length - this.maxBodyRows());
		this.scrollTop = Math.min(this.scrollTop, maxScrollTop);
		if (this.selectedIndex < this.scrollTop) this.scrollTop = this.selectedIndex;
		if (this.selectedIndex >= this.scrollTop + this.maxBodyRows()) {
			this.scrollTop = this.selectedIndex - this.maxBodyRows() + 1;
		}
	}

	private moveSelection(delta: number): void {
		const report = calculateBreakdown(this.pi, this.ctx);
		this.rebuildRows(report);
		if (this.rows.length === 0) return;
		this.selectedIndex =
			(this.selectedIndex + delta + this.rows.length) % this.rows.length;
		this.rebuildRows(report);
		this.tui.requestRender();
	}

	private setExpanded(expanded: boolean): void {
		const row = this.rows[this.selectedIndex];
		if (!row?.item.children.length) return;
		if (expanded) this.expanded.add(row.item.id);
		else this.expanded.delete(row.item.id);
		this.tui.requestRender();
	}

	handleInput(data: string): void {
		if (this.keybindings.matches(data, "tui.select.cancel")) {
			this.done();
			return;
		}
		if (this.keybindings.matches(data, "tui.select.up") || data === "k") {
			this.moveSelection(-1);
			return;
		}
		if (this.keybindings.matches(data, "tui.select.down") || data === "j") {
			this.moveSelection(1);
			return;
		}
		if (data === "h") {
			this.setExpanded(false);
			return;
		}
		if (data === "l") {
			this.setExpanded(true);
			return;
		}
		if (this.keybindings.matches(data, "tui.select.confirm")) {
			const row = this.rows[this.selectedIndex];
			if (row?.item.children.length > 0) {
				if (this.expanded.has(row.item.id)) this.expanded.delete(row.item.id);
				else this.expanded.add(row.item.id);
				this.tui.requestRender();
			}
		}
	}

	render(width: number): string[] {
		const report = calculateBreakdown(this.pi, this.ctx);
		this.rebuildRows(report);

		const innerWidth = Math.max(1, width - 2);
		const window = report.contextWindow;
		const estimatedPercent = window > 0 ? (report.estimatedTotal / window) * 100 : 0;
		const displayedTotal = report.reportedTotal ?? report.estimatedTotal;
		const displayedPercent = window > 0 ? (displayedTotal / window) * 100 : 0;
		const free = Math.max(0, window - displayedTotal);
		const freePercent = window > 0 ? Math.max(0, 100 - displayedPercent) : 0;
		const usageColor: "success" | "warning" | "error" =
			displayedPercent > 90 ? "error" : displayedPercent > 70 ? "warning" : "success";
		const border = (left: string, fill: string, right: string) =>
			truncateToWidth(
				this.theme.fg("border", `${left}${fill.repeat(Math.max(0, width - 2))}${right}`),
				width,
				"",
			);
		const content = (text: string, selected = false) => {
			const line = padLine(text, innerWidth);
			return selected ? this.theme.bg("selectedBg", line) : line;
		};
		const topLevelPercent = (tokens: number) =>
			window > 0 ? `(${((tokens / window) * 100).toFixed(1)}%)` : "(?)";

		const bodyLimit = this.maxBodyRows();
		const visibleRows = this.rows.slice(this.scrollTop, this.scrollTop + bodyLimit);
		const body = visibleRows.map((row, index) => {
			const absoluteIndex = this.scrollTop + index;
			const indent = "  ".repeat(row.depth);
			const marker = row.item.children.length > 0
				? this.expanded.has(row.item.id)
					? "▾ "
					: "▸ "
				: "  ";
			const label = `${indent}${marker}${row.item.label}`;
			const percent = row.depth === 0
				? topLevelPercent(row.item.tokens)
				: row.percentOf > 0
					? `(${((row.item.tokens / row.percentOf) * 100).toFixed(1)}%)`
					: "(?)";
			const gap = " ".repeat(Math.max(2, 34 - visibleWidth(label)));
			const line = `${this.theme.fg("text", label)}${gap}${this.theme.fg("muted", formatTokens(row.item.tokens))} ${this.theme.fg("dim", percent)}`;
			return content(line, absoluteIndex === this.selectedIndex);
		});

		const model = this.ctx.model?.id ?? "no model";
		const summary = report.reportedTotal !== undefined
			? `Provider total: ${formatTokens(report.reportedTotal)} / ${formatTokens(window)} (${displayedPercent.toFixed(1)}%) · ${model}`
			: `Estimated: ${formatTokens(report.estimatedTotal)} / ${formatTokens(window)} (${estimatedPercent.toFixed(1)}%) · ${model}`;
		const freeLine = window > 0
			? `${this.theme.fg("text", report.reportedTotal !== undefined ? "Free space (reported)" : "Free space")}  ${this.theme.fg(usageColor, formatTokens(free))} ${this.theme.fg("dim", `(${freePercent.toFixed(1)}%)`)}`
			: `${this.theme.fg("text", "Free space")}  ${this.theme.fg("muted", "unknown")}`;
		const range = this.rows.length > 0
			? `Showing ${this.scrollTop + 1}-${Math.min(this.rows.length, this.scrollTop + bodyLimit)} of ${this.rows.length}`
			: "No context items";
		const up = this.keybindings.getKeys("tui.select.up")[0] ?? "↑";
		const down = this.keybindings.getKeys("tui.select.down")[0] ?? "↓";
		const confirm = this.keybindings.getKeys("tui.select.confirm")[0] ?? "enter";
		const cancel = this.keybindings.getKeys("tui.select.cancel")[0] ?? "esc";

		const lines = [
			border("╭", "─", "╮"),
			content(this.theme.fg("accent", this.theme.bold("Context usage"))),
			content(this.theme.fg("muted", summary)),
			content(""),
			...body,
			content(""),
			content(freeLine),
			content(this.theme.fg("dim", `${range} · ${up}${down}/jk navigate · h/l collapse/expand · ${confirm} toggle · ${cancel} close`)),
			content(this.theme.fg("dim", "Category breakdown is estimated; provider total is authoritative when available.")),
			border("╰", "─", "╯"),
		];

		return lines.map((line) => truncateToWidth(line, width, ""));
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("context-usage", {
		description: "Show estimated context usage",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/context-usage is only available in interactive mode", "warning");
				return;
			}

			await ctx.ui.custom<void>(
				(tui, theme, keybindings, done) =>
					new ContextUsageOverlay(pi, ctx, tui, theme, keybindings, () => done()),
				{
					overlay: true,
					overlayOptions: {
						width: "75%",
						minWidth: 64,
						maxHeight: "85%",
						anchor: "center",
						margin: 2,
					},
				},
			);
		},
	});
}
