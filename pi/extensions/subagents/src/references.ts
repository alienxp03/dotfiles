/** Resolve model-facing subagent references without guessing on duplicate names. */

import type { SubagentSnapshot } from "./domain.ts";

export interface AmbiguousSubagentReference {
  readonly reference: string;
  readonly ids: ReadonlyArray<string>;
}

export interface SubagentReferenceResolution {
  readonly ids: ReadonlyArray<string>;
  readonly unknown: ReadonlyArray<string>;
  readonly ambiguous: ReadonlyArray<AmbiguousSubagentReference>;
}

/**
 * Resolve exact runtime IDs first, then exact human-readable titles.
 * Duplicate titles stay unresolved so a wait cannot target the wrong agent.
 */
export function resolveSubagentReferences(
  references: ReadonlyArray<string>,
  snapshots: ReadonlyArray<Pick<SubagentSnapshot, "id" | "title">>,
): SubagentReferenceResolution {
  const byId = new Map(snapshots.map((snap) => [snap.id, snap]));
  const byTitle = new Map<string, string[]>();
  for (const snap of snapshots) {
    const ids = byTitle.get(snap.title) ?? [];
    ids.push(snap.id);
    byTitle.set(snap.title, ids);
  }

  const ids: string[] = [];
  const unknown: string[] = [];
  const ambiguous: AmbiguousSubagentReference[] = [];
  const resolvedIds = new Set<string>();

  for (const reference of [...new Set(references)]) {
    const byIdMatch = byId.get(reference);
    if (byIdMatch) {
      if (!resolvedIds.has(byIdMatch.id)) {
        resolvedIds.add(byIdMatch.id);
        ids.push(byIdMatch.id);
      }
      continue;
    }

    const titleMatches = byTitle.get(reference) ?? [];
    if (titleMatches.length === 1) {
      const id = titleMatches[0];
      if (!resolvedIds.has(id)) {
        resolvedIds.add(id);
        ids.push(id);
      }
    } else if (titleMatches.length > 1) {
      ambiguous.push({ reference, ids: titleMatches });
    } else {
      unknown.push(reference);
    }
  }

  return { ids, unknown, ambiguous };
}
