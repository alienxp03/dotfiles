import { getPreferenceValues } from "@raycast/api";
import { readdir, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { extname, join, resolve } from "node:path";

const IMAGE_EXTENSIONS = new Set([
  ".bmp",
  ".gif",
  ".jpeg",
  ".jpg",
  ".png",
  ".tif",
  ".tiff",
  ".webp",
]);

export type Screenshot = {
  name: string;
  path: string;
  modifiedAt: number;
  size: number;
};

export type RetentionPeriod = "unlimited" | "3-months" | "6-months" | "12-months";

type Preferences = {
  screenshotsDirectory?: string;
  retentionPeriod?: RetentionPeriod;
};

const RETENTION_MONTHS: Record<Exclude<RetentionPeriod, "unlimited">, number> = {
  "3-months": 3,
  "6-months": 6,
  "12-months": 12,
};

export function screenshotsDirectory(): string {
  const configured = getPreferenceValues<Preferences>().screenshotsDirectory?.trim();

  if (!configured) {
    return join(homedir(), "Desktop");
  }

  if (configured === "~") {
    return homedir();
  }

  if (configured.startsWith("~/")) {
    return join(homedir(), configured.slice(2));
  }

  return resolve(configured);
}

export function screenshotRetentionPeriod(): RetentionPeriod {
  const configured = getPreferenceValues<Preferences>().retentionPeriod;

  switch (configured) {
    case "3-months":
    case "6-months":
    case "12-months":
    case "unlimited":
      return configured;
    default:
      return "unlimited";
  }
}

export function retentionCutoff(
  period: RetentionPeriod,
  now = new Date(),
): number | undefined {
  if (period === "unlimited") {
    return undefined;
  }

  const cutoff = new Date(now);
  cutoff.setMonth(cutoff.getMonth() - RETENTION_MONTHS[period]);
  return cutoff.getTime();
}

export async function findScreenshots(directory: string): Promise<Screenshot[]> {
  let entries;

  try {
    entries = await readdir(directory, { withFileTypes: true });
  } catch (error) {
    if (isFileSystemError(error, "ENOENT")) {
      return [];
    }

    throw error;
  }

  const screenshots = await Promise.all(
    entries
      .filter((entry) => entry.isFile() && IMAGE_EXTENSIONS.has(extname(entry.name).toLowerCase()))
      .map(async (entry): Promise<Screenshot | undefined> => {
        const path = join(directory, entry.name);

        try {
          const details = await stat(path);
          return {
            name: entry.name,
            path,
            modifiedAt: details.mtimeMs,
            size: details.size,
          };
        } catch {
          return undefined;
        }
      }),
  );

  return screenshots
    .filter((screenshot): screenshot is Screenshot => screenshot !== undefined)
    .sort(
      (left, right) =>
        right.modifiedAt - left.modifiedAt || left.name.localeCompare(right.name),
    );
}

function isFileSystemError(error: unknown, code: string): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === code
  );
}
