import type {
  AutocompleteItem,
  AutocompleteProvider,
} from "@earendil-works/pi-tui";
import type { SubagentSnapshot } from "./domain.ts";

export interface DirectSubagentPrompt {
  readonly reference: string;
  readonly prompt: string;
}

/** Parse a prompt addressed to one subagent, e.g. `@review-api fix this`. */
export function parseDirectSubagentPrompt(
  text: string,
): DirectSubagentPrompt | undefined {
  const match =
    /^@(?:"((?:\\.|[^"\\])*)"|([^\s]+))(?:\s+([\s\S]*))?$/.exec(text);
  const prompt = match?.[3]?.trimStart();
  if (!match || !prompt?.trim()) return undefined;

  return {
    reference: (match[1] ?? match[2] ?? "").replace(/\\(["\\])/g, "$1"),
    prompt,
  };
}

/** Return whether the editor contains only a direct subagent tag. */
export function isDirectSubagentTagDraft(text: string): boolean {
  return /^@(?:[^\s]*|"(?:\\.|[^"\\])*")$/.test(text.trimEnd());
}

/** Return the editor prefix when it is completing a direct subagent tag. */
export function directSubagentTagPrefix(text: string): string | undefined {
  if (/^@[^\s]*$/.test(text)) return text;
  if (/^@"(?:\\.|[^"\\])*$/.test(text)) return text;
  return undefined;
}

export function directSubagentTagValue(title: string): string {
  return /\s/.test(title) || title.includes('"')
    ? `@"${title.replace(/(["\\])/g, "\\$1")}"`
    : `@${title}`;
}

export function createDirectSubagentAutocomplete(
  current: AutocompleteProvider,
  getSnapshots: () => Promise<ReadonlyArray<SubagentSnapshot>>,
): AutocompleteProvider {
  return {
    triggerCharacters: ["@"],
    async getSuggestions(lines, cursorLine, cursorCol, options) {
      const line = lines[cursorLine] ?? "";
      const beforeCursor = line.slice(0, cursorCol);
      const prefix = directSubagentTagPrefix(beforeCursor);
      if (prefix === undefined) {
        return current.getSuggestions(lines, cursorLine, cursorCol, options);
      }

      const snapshots = await getSnapshots();
      if (options.signal.aborted) return null;
      const query = (
        prefix.startsWith('@"') ? prefix.slice(2) : prefix.slice(1)
      ).toLowerCase();
      const items = snapshots
        .filter((snap) => snap.title.toLowerCase().includes(query))
        .map((snap): AutocompleteItem => ({
          value: directSubagentTagValue(snap.title),
          label: directSubagentTagValue(snap.title),
          description: `${snap.status} · ${snap.backend} · ${snap.id}`,
        }));

      return items.length > 0
        ? { prefix, items }
        : current.getSuggestions(lines, cursorLine, cursorCol, options);
    },
    applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
      if (
        directSubagentTagPrefix(lines[cursorLine]?.slice(0, cursorCol) ?? "") === prefix
      ) {
        const line = lines[cursorLine] ?? "";
        const beforePrefix = line.slice(
          0,
          Math.max(0, cursorCol - prefix.length),
        );
        const afterCursor = line.slice(cursorCol);
        const separator = /^\s/.test(afterCursor) ? "" : " ";
        const newLines = [...lines];
        newLines[cursorLine] = `${beforePrefix}${item.value}${separator}${afterCursor}`;
        return {
          lines: newLines,
          cursorLine,
          cursorCol: beforePrefix.length + item.value.length + separator.length,
        };
      }
      return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
    },
    shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
      return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
    },
  };
}
