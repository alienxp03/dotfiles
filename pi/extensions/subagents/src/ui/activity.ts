import type { Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import {
  formatElapsed,
  type SubagentSnapshot,
  type TranscriptPart,
} from "../domain.ts";
import { formatCompactTokens, formatDuration } from "../format.ts";
import type { SubagentReadModel } from "../manager.ts";
import { sanitizeText } from "./transcript.ts";

export const MAX_VISIBLE_ACTIVE_AGENTS = 2;
const ACTIVITY_PREVIEW_MAX_LENGTH = 240;

export interface ActiveSubagentSelection {
  readonly active: ReadonlyArray<SubagentSnapshot>;
  readonly visible: ReadonlyArray<SubagentSnapshot>;
  readonly hiddenCount: number;
}

/** Select running agents in creation order with deterministic ties. */
export function selectActiveSubagents(
  snapshots: ReadonlyArray<SubagentSnapshot>,
  limit = MAX_VISIBLE_ACTIVE_AGENTS,
): ActiveSubagentSelection {
  const active = snapshots
    .filter((snap) => snap.status === "running")
    .sort((a, b) => {
      const created = a.createdAt - b.createdAt;
      if (created !== 0) return created;
      return a.id.localeCompare(b.id);
    });
  const visible = active.slice(0, Math.max(0, limit));
  return {
    active,
    visible,
    hiddenCount: active.length - visible.length,
  };
}

function compactText(text: string, maxLength = ACTIVITY_PREVIEW_MAX_LENGTH) {
  const clean = sanitizeText(text).replace(/\s+/g, " ").trim();
  if (clean.length <= maxLength) return clean;
  return `${clean.slice(0, Math.max(0, maxLength - 1))}…`;
}

function partActivity(part: TranscriptPart): string | undefined {
  switch (part.type) {
    case "text": {
      const text = compactText(part.text);
      return text ? `assistant: ${text}` : undefined;
    }
    case "toolCall":
      return part.argsPreview
        ? `${part.name}: ${compactText(part.argsPreview)}`
        : part.name;
    case "thinking":
      return "thinking";
  }
}

/** Return one safe, single-line description of the latest meaningful action. */
export function latestActivity(snap: SubagentSnapshot): string {
  const tool = snap.liveTools.at(-1);
  if (tool) {
    const detail = tool.outputPreview || tool.argsPreview;
    return compactText(detail ? `${tool.name}: ${detail}` : tool.name);
  }

  const queued = snap.queued[0];
  if (queued) {
    const text = compactText(queued.text);
    return text ? `queued ${queued.kind}: ${text}` : `queued ${queued.kind}`;
  }

  const live = snap.liveAssistant;
  if (live?.text.trim()) return compactText(`assistant: ${live.text}`);
  if (live?.thinking.trim()) return "thinking";

  for (let i = snap.transcript.length - 1; i >= 0; i--) {
    const item = snap.transcript[i];
    if (item.kind === "toolResult") {
      return compactText(
        item.outputPreview
          ? `${item.name}: ${item.outputPreview}`
          : `${item.name} ${item.isError ? "failed" : "completed"}`,
      );
    }
    if (item.kind === "assistant") {
      for (let j = item.parts.length - 1; j >= 0; j--) {
        const activity = partActivity(item.parts[j]);
        if (activity) return compactText(activity);
      }
    }
  }

  return "starting";
}

function formatTokenUsage(snap: SubagentSnapshot): string {
  return snap.usage.tokens === undefined
    ? "—"
    : formatCompactTokens(snap.usage.tokens);
}

/** Plain row text, useful for tests and non-colour callers. */
export function formatActivityRow(snap: SubagentSnapshot): string {
  return `${compactText(snap.title, 80)} · ${snap.backend} · ${formatTokenUsage(snap)} · ${formatElapsed(snap)} · ${latestActivity(snap)}`;
}

const CLI_ACTIVITY_NAMES = new Set([
  "bash",
  "command",
  "exec",
  "shell",
  "terminal",
]);

function styledActivity(theme: Theme, activity: string) {
  const separator = activity.indexOf(":");
  if (separator < 0) return theme.fg("muted", activity);
  const label = activity.slice(0, separator);
  const detail = activity.slice(separator + 1);
  const labelColor = CLI_ACTIVITY_NAMES.has(label.toLowerCase())
    ? "bashMode"
    : "mdHeading";
  return (
    theme.fg(labelColor, label) +
    theme.fg("dim", ":") +
    theme.fg("toolOutput", detail)
  );
}

interface ActivityColumnLayout {
  readonly marker: number;
  readonly title: number;
  readonly backend?: number;
  readonly tokens?: number;
  readonly elapsed?: number;
  readonly activity: number;
}

const ACTIVITY_COLUMN_GAP = 3; // space + separator + space

/** Keep the compact activity panel aligned without hiding its useful preview. */
export function activityColumnLayout(width: number): ActivityColumnLayout {
  const available = Math.max(1, width);
  const marker = 1;
  const title = available >= 60 ? 18 : available >= 40 ? 14 : 10;
  const backend = available >= 58 ? 7 : undefined;
  // Keep the activity preview readable on narrow terminals; the token column
  // appears once there is enough room for both metadata and a useful preview.
  const tokens = available >= 70 ? 7 : undefined;
  const elapsed = available >= 36 ? 6 : undefined;
  const fixedWidths = [title, backend, tokens, elapsed].filter(
    (value): value is number => value !== undefined,
  );
  const columnCount = fixedWidths.length + 2; // marker + activity
  const fixed =
    marker +
    fixedWidths.reduce((total, value) => total + value, 0) +
    (columnCount - 1) * ACTIVITY_COLUMN_GAP;

  return {
    marker,
    title,
    backend,
    tokens,
    elapsed,
    activity: Math.max(1, available - fixed),
  };
}

function activityColumn(theme: Theme, text: string, width: number) {
  const truncated = truncateToWidth(text, width, theme.fg("dim", "…"));
  return truncated + " ".repeat(Math.max(0, width - visibleWidth(truncated)));
}

function formatActivityTableRow(
  theme: Theme,
  snap: SubagentSnapshot,
  width: number,
) {
  const layout = activityColumnLayout(width);
  const separator = theme.fg("borderMuted", "│");
  const gap = ` ${separator} `;
  const columns = [
    activityColumn(theme, statusGlyph(theme), layout.marker),
    activityColumn(
      theme,
      theme.fg("text", compactText(snap.title, 80)),
      layout.title,
    ),
    ...(layout.backend === undefined
      ? []
      : [activityColumn(theme, theme.fg("muted", snap.backend), layout.backend)]),
    ...(layout.tokens === undefined
      ? []
      : [
          activityColumn(
            theme,
            theme.fg("muted", formatTokenUsage(snap)),
            layout.tokens,
          ),
        ]),
    ...(layout.elapsed === undefined
      ? []
      : [
          activityColumn(
            theme,
            theme.fg("muted", formatElapsed(snap)),
            layout.elapsed,
          ),
        ]),
    activityColumn(theme, styledActivity(theme, latestActivity(snap)), layout.activity),
  ];
  return columns.join(gap);
}

function padBoxContent(theme: Theme, content: string, width: number) {
  const innerWidth = Math.max(1, width - 2);
  const visible = truncateToWidth(` ${content}`, innerWidth, "");
  return (
    theme.fg("border", "│") +
    visible +
    " ".repeat(Math.max(0, innerWidth - visibleWidth(visible))) +
    theme.fg("border", "│")
  );
}

function borderBoxLine(
  theme: Theme,
  left: string,
  right: string,
  label: string,
  width: number,
) {
  const innerWidth = Math.max(1, width - 2);
  const visibleLabel = truncateToWidth(` ${label} `, innerWidth, "");
  const fill = Math.max(0, innerWidth - visibleWidth(visibleLabel));
  return (
    theme.fg("border", left) +
    visibleLabel +
    theme.fg("border", "─".repeat(fill) + right)
  );
}

function statusGlyph(theme: Theme) {
  return theme.fg("warning", "■");
}

/** Persistent, read-only activity panel rendered above Pi's editor. */
export class SubagentActivityWidget implements Component {
  private readonly tui: TUI;
  private readonly theme: Theme;
  private readonly view: SubagentReadModel;
  private readonly unsubscribe: () => void;
  private readonly ticker: ReturnType<typeof setInterval>;
  private renderTimer?: ReturnType<typeof setTimeout>;
  private closed = false;

  constructor(tui: TUI, theme: Theme, view: SubagentReadModel) {
    this.tui = tui;
    this.theme = theme;
    this.view = view;
    this.unsubscribe = view.subscribe(() => this.scheduleRender());
    this.ticker = setInterval(() => {
      if (this.view.list().some((snap) => snap.status === "running")) {
        this.tui.requestRender();
      }
    }, 1000);
  }

  private scheduleRender() {
    if (this.renderTimer || this.closed) return;
    this.renderTimer = setTimeout(() => {
      this.renderTimer = undefined;
      if (!this.closed) this.tui.requestRender();
    }, 50);
  }

  private cleanup() {
    if (this.closed) return;
    this.closed = true;
    this.unsubscribe();
    clearInterval(this.ticker);
    if (this.renderTimer) clearTimeout(this.renderTimer);
    this.renderTimer = undefined;
  }

  dispose(): void {
    this.cleanup();
  }

  render(width: number): string[] {
    const selection = selectActiveSubagents(this.view.list());
    const stats = this.view.stats();
    const dot = this.theme.fg("dim", " · ");
    const context =
      stats.contextTokens === undefined
        ? ""
        : dot +
          this.theme.fg(
            "muted",
            `${formatCompactTokens(stats.contextTokens)} ctx tokens`,
          );
    const header = borderBoxLine(
      this.theme,
      "╭",
      "╮",
      this.theme.fg("accent", "Subagents") +
        dot +
        this.theme.fg("warning", `${selection.active.length} running`) +
        dot +
        this.theme.fg("muted", `${stats.totalAgents} total`) +
        dot +
        this.theme.fg("muted", `${formatDuration(stats.wallTimeMs)} wall`) +
        dot +
        this.theme.fg(
          "muted",
          `${formatDuration(stats.agentTimeMs)} total`,
        ) +
        context,
      width,
    );
    const rows = selection.visible.map((snap) =>
      padBoxContent(
        this.theme,
        formatActivityTableRow(this.theme, snap, Math.max(1, width - 3)),
        width,
      ),
    );
    const more =
      selection.hiddenCount > 0
        ? this.theme.fg("dim", `+${selection.hiddenCount} more`)
        : "";
    return [
      header,
      ...rows,
      borderBoxLine(this.theme, "╰", "╯", more, width),
    ];
  }

  invalidate(): void {}
}
