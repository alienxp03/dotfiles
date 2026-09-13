import type { Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { type Editor, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
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

/** Omit the provider prefix to keep model metadata compact in the preview. */
function compactModelLabel(modelLabel: string | undefined): string {
  if (!modelLabel) return "?";
  const separator = modelLabel.indexOf("/");
  return separator < 0 ? modelLabel : modelLabel.slice(separator + 1);
}

export function formatModelAndReasoning(snap: SubagentSnapshot): string {
  return `${compactModelLabel(snap.meta.modelLabel)} (${snap.meta.reasoningEffort ?? "default"})`;
}

/** Plain row text, useful for tests and non-colour callers. */
export function formatActivityRow(snap: SubagentSnapshot): string {
  return `${compactText(snap.title, 80)} · ${snap.backend} · ${formatModelAndReasoning(snap)} · ${formatTokenUsage(snap)} · ${formatElapsed(snap)} · ${latestActivity(snap)}`;
}

const CLI_ACTIVITY_NAMES = new Set([
  "bash",
  "command",
  "exec",
  "shell",
  "terminal",
]);

function styledActivity(
  theme: Theme,
  activity: string,
  plainColor: ThemeColor = "muted",
) {
  const separator = activity.indexOf(":");
  if (separator < 0) return theme.fg(plainColor, activity);
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
  readonly model?: number;
  readonly tokens?: number;
  readonly elapsed?: number;
  readonly activity: number;
}

const ACTIVITY_COLUMN_GAP = 3; // space + separator + space
const ACTIVITY_MODEL_WIDTH = 24;

/** Keep the compact activity panel aligned without hiding its useful preview. */
export function activityColumnLayout(width: number): ActivityColumnLayout {
  const available = Math.max(1, width);
  const marker = 1;
  const title = available >= 60 ? 20 : available >= 40 ? 14 : 10;
  const backend = available >= 58 ? 5 : undefined;
  // Keep the model and reasoning together so the preview remains scannable.
  const model = available >= 88 ? ACTIVITY_MODEL_WIDTH : undefined;
  // Keep the activity preview readable on narrow terminals; the token column
  // appears once there is enough room for both metadata and a useful preview.
  const tokens = available >= 70 ? 7 : undefined;
  const elapsed = available >= 36 ? 6 : undefined;
  const fixedWidths = [title, backend, model, tokens, elapsed].filter(
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
    model,
    tokens,
    elapsed,
    activity: Math.max(1, available - fixed),
  };
}

function activityColumn(theme: Theme, text: string, width: number) {
  const truncated = truncateToWidth(text, width, theme.fg("dim", "…"));
  return truncated + " ".repeat(Math.max(0, width - visibleWidth(truncated)));
}

function boldText(theme: Theme, text: string) {
  const bold = (theme as Theme & {
    bold?: (value: string) => string;
  }).bold;
  return typeof bold === "function" ? bold.call(theme, text) : text;
}

function formatActivityTableRow(
  theme: Theme,
  snap: SubagentSnapshot,
  width: number,
  selected = false,
) {
  const layout = activityColumnLayout(width);
  const separator = theme.fg("borderMuted", "│");
  const gap = ` ${separator} `;
  const columns = [
    activityColumn(theme, selected ? theme.fg("accent", "›") : statusGlyph(theme, snap.status), layout.marker),
    activityColumn(
      theme,
      selected
        ? theme.fg("accent", boldText(theme, compactText(snap.title, 80)))
        : theme.fg("text", boldText(theme, compactText(snap.title, 80))),
      layout.title,
    ),
    ...(layout.backend === undefined
      ? []
      : [activityColumn(theme, theme.fg("text", snap.backend), layout.backend)]),
    ...(layout.model === undefined
      ? []
      : [
          activityColumn(
            theme,
            theme.fg("text", formatModelAndReasoning(snap)),
            layout.model,
          ),
        ]),
    ...(layout.tokens === undefined
      ? []
      : [
          activityColumn(
            theme,
            theme.fg("text", formatTokenUsage(snap)),
            layout.tokens,
          ),
        ]),
    ...(layout.elapsed === undefined
      ? []
      : [
          activityColumn(
            theme,
            theme.fg("text", formatElapsed(snap)),
            layout.elapsed,
          ),
        ]),
  ];
  return columns.join(gap);
}

function formatActivityDetailRow(theme: Theme, snap: SubagentSnapshot) {
  return (
    theme.fg("dim", "  └─") +
    " " +
    styledActivity(theme, latestActivity(snap))
  );
}

function padBoxContent(
  theme: Theme,
  content: string,
  width: number,
  selected = false,
) {
  const innerWidth = Math.max(1, width - 2);
  const visible = truncateToWidth(` ${content}`, innerWidth, "");
  const body = visible + " ".repeat(Math.max(0, innerWidth - visibleWidth(visible)));
  const themeWithBackground = theme as Theme & {
    bg?: (color: string, text: string) => string;
  };
  const styledBody =
    selected && typeof themeWithBackground.bg === "function"
      ? themeWithBackground.bg("selectedBg", body)
      : body;
  return (
    theme.fg(selected ? "borderAccent" : "border", "│") +
    styledBody +
    theme.fg(selected ? "borderAccent" : "border", "│")
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

function statusGlyph(theme: Theme, status: SubagentSnapshot["status"]) {
  if (status === "done") return theme.fg("success", "✓");
  if (status === "error") return theme.fg("error", "✗");
  if (status !== "running") return theme.fg("muted", "–");
  return theme.fg("warning", "■");
}

function isEditor(component: Component | null | undefined): component is Editor {
  // Host and extension may load different pi-tui versions; instanceof would
  // reject the host editor even though its public editor API is compatible.
  const editor = component as Partial<Editor> | undefined;
  return typeof editor?.getText === "function" &&
    typeof editor?.isShowingAutocomplete === "function";
}

export interface ActivityNavigation {
  canFocus(): boolean;
  open(id: string): Promise<void>;
  onError(error: unknown): void;
}

/** Persistent activity panel rendered above Pi's editor. */
export class SubagentActivityWidget implements Component {
  private readonly tui: TUI;
  private readonly theme: Theme;
  private readonly view: SubagentReadModel;
  private readonly unsubscribe: () => void;
  private readonly ticker: ReturnType<typeof setInterval>;
  private renderTimer?: ReturnType<typeof setTimeout>;
  private closed = false;
  private seenIds = new Set<string>();
  private previewIds = new Set<string>();
  private readonly navigation?: ActivityNavigation;
  private removeInputListener?: () => void;
  private editor?: Component;
  private selectedId?: string;
  private selectedIndex = 0;
  private opening = false;
  private escapeGuardUntil = 0;

  private focusedComponent() {
    // Concrete Pi renderers expose this public method, though TUI's interface
    // omits it. Disable navigation gracefully on renderers without it.
    return (this.tui as TUI & { getFocusedComponent?: () => Component | null })
      .getFocusedComponent?.();
  }

  private previews() {
    return this.view.list()
      .filter((snap) => this.previewIds.has(snap.id) || snap.status === "running")
      .sort((a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id));
  }

  private reconcileSelection(previews = this.previews()) {
    const index = previews.findIndex((snap) => snap.id === this.selectedId);
    this.selectedIndex = index >= 0 ? index : Math.max(0, Math.min(this.selectedIndex, previews.length - 1));
    this.selectedId = previews[this.selectedIndex]?.id;
  }

  handleInput(data: string): void {
    if (!this.editor || this.opening) return;
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
      this.escapeGuardUntil = Date.now() + 500;
      this.tui.setFocus(this.editor);
      this.editor = undefined;
    } else {
      const previews = this.previews();
      this.reconcileSelection(previews);
      if (data === "j" || matchesKey(data, "down")) {
        this.selectedIndex = Math.min(previews.length - 1, this.selectedIndex + 1);
        this.selectedId = previews[this.selectedIndex]?.id;
      } else if (data === "k" || matchesKey(data, "up")) {
        this.selectedIndex = Math.max(0, this.selectedIndex - 1);
        this.selectedId = previews[this.selectedIndex]?.id;
      } else if (matchesKey(data, "enter") && this.selectedId && this.navigation) {
        this.opening = true;
        void this.navigation.open(this.selectedId)
          .catch((error) => this.navigation?.onError(error))
          .finally(() => {
            this.opening = false;
            if (!this.closed) this.tui.requestRender();
          });
      }
    }
    this.tui.requestRender();
  }

  private updatePreview() {
    const snapshots = this.view.list();
    const added = snapshots.filter((snap) => !this.seenIds.has(snap.id));
    if (added.length > 0) {
      // Only a spawn retires settled previews; ordinary updates keep them.
      this.previewIds = new Set([
        ...snapshots.filter((snap) => snap.status === "running").map((snap) => snap.id),
        ...added.map((snap) => snap.id),
      ]);
    }
    for (const snap of snapshots) this.seenIds.add(snap.id);
  }

  constructor(tui: TUI, theme: Theme, view: SubagentReadModel, navigation?: ActivityNavigation) {
    this.navigation = navigation;
    this.tui = tui;
    this.theme = theme;
    this.view = view;
    this.updatePreview();
    if (navigation) {
      this.removeInputListener = tui.addInputListener((data) => {
        if (this.closed || tui.hasOverlay()) return;
        if (Date.now() < this.escapeGuardUntil && matchesKey(data, "escape")) return { consume: true };
        const focused = this.focusedComponent();
        if (
          matchesKey(data, "down") && isEditor(focused) &&
          focused.getText() === "" && !focused.isShowingAutocomplete() &&
          navigation.canFocus() && this.previews().length > 0
        ) {
          this.editor = focused;
          this.reconcileSelection();
          tui.setFocus(this);
          tui.requestRender();
          return { consume: true };
        }
        return undefined;
      });
    }
    this.unsubscribe = view.subscribe(() => {
      this.updatePreview();
      this.scheduleRender();
    });
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
    this.removeInputListener?.();
    if (this.editor && this.focusedComponent() === this) this.tui.setFocus(this.editor);
    this.editor = undefined;
    this.unsubscribe();
    clearInterval(this.ticker);
    if (this.renderTimer) clearTimeout(this.renderTimer);
    this.renderTimer = undefined;
  }

  dispose(): void {
    this.cleanup();
  }

  render(width: number): string[] {
    const snapshots = this.view.list();
    const selection = selectActiveSubagents(snapshots);
    const previews = this.previews();
    this.reconcileSelection(previews);
    const start = this.editor ? Math.max(0, this.selectedIndex - MAX_VISIBLE_ACTIVE_AGENTS + 1) : 0;
    const visible = previews.slice(start, start + MAX_VISIBLE_ACTIVE_AGENTS);
    const hiddenCount = previews.length - visible.length;
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
    const running =
      selection.active.length === 0
        ? ""
        : dot +
          this.theme.fg("warning", `${selection.active.length} running`);
    const header = borderBoxLine(
      this.theme,
      "╭",
      "╮",
      this.theme.fg("accent", "Subagents") +
        running +
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
    const rows = visible.flatMap((snap) => {
      const selected = !!this.editor && snap.id === this.selectedId;
      return [
        padBoxContent(
          this.theme,
          formatActivityTableRow(this.theme, snap, Math.max(1, width - 3), selected),
          width,
          selected,
        ),
        padBoxContent(
          this.theme,
          formatActivityDetailRow(this.theme, snap),
          width,
          selected,
        ),
      ];
    });
    const more =
      hiddenCount > 0
        ? this.theme.fg("dim", `+${hiddenCount} more`)
        : "";
    return [
      header,
      ...rows,
      borderBoxLine(this.theme, "╰", "╯", more, width),
    ];
  }

  invalidate(): void {}
}
