import { realpathSync } from "node:fs";
import { join, resolve } from "node:path";
import type { LoadExtensionsResult } from "@earendil-works/pi-coding-agent";

/** Exclude the foreground cmux lifecycle hook from in-process child sessions. */
export function childExtensionsOverride(agentDir: string) {
  const cmuxSessionPath = canonicalPath(join(agentDir, "extensions", "cmux-session.ts"));
  return (base: LoadExtensionsResult): LoadExtensionsResult => ({
    ...base,
    extensions: base.extensions.filter(
      (extension) => canonicalPath(extension.resolvedPath) !== cmuxSessionPath,
    ),
    errors: base.errors.filter(
      (error) => canonicalPath(error.path) !== cmuxSessionPath,
    ),
  });
}

function canonicalPath(path: string): string {
  try {
    return realpathSync(path);
  } catch {
    return resolve(path);
  }
}
