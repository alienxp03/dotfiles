import { LocalStorage } from "@raycast/api";
import { extractText } from "./ocr";
import { findScreenshots, type Screenshot } from "./screenshots";

const INDEX_KEY = "screenshot-index-v1";

export type IndexedScreenshot = Screenshot & {
  text: string;
};

type IndexEntry = {
  size: number;
  modifiedAt: number;
  text: string;
};

type StoredIndex = {
  version: 1;
  directory: string;
  files: Record<string, IndexEntry>;
};

export type IndexProgress = {
  completed: number;
  total: number;
  indexed: number;
  reused: number;
};

export type IndexResult = {
  screenshots: IndexedScreenshot[];
  indexed: number;
  reused: number;
};

async function loadIndex(directory: string): Promise<StoredIndex | undefined> {
  const value = await LocalStorage.getItem<string>(INDEX_KEY);

  if (!value) {
    return undefined;
  }

  try {
    const parsed = JSON.parse(value) as StoredIndex;
    if (parsed.version !== 1 || parsed.directory !== directory || !parsed.files) {
      return undefined;
    }

    return parsed;
  } catch {
    return undefined;
  }
}

async function saveIndex(index: StoredIndex): Promise<void> {
  await LocalStorage.setItem(INDEX_KEY, JSON.stringify(index));
}

export async function getIndexedScreenshots(
  directory: string,
): Promise<IndexedScreenshot[]> {
  const [screenshots, index] = await Promise.all([
    findScreenshots(directory),
    loadIndex(directory),
  ]);

  return screenshots.map((screenshot) => ({
    ...screenshot,
    text: index?.files[screenshot.path]?.text ?? "",
  }));
}

export async function indexScreenshots(
  directory: string,
  onProgress?: (progress: IndexProgress) => void,
): Promise<IndexResult> {
  const [screenshots, previous] = await Promise.all([
    findScreenshots(directory),
    loadIndex(directory),
  ]);
  const files: Record<string, IndexEntry> = {};
  const indexedScreenshots: IndexedScreenshot[] = [];
  let indexed = 0;
  let reused = 0;

  for (let index = 0; index < screenshots.length; index += 1) {
    const screenshot = screenshots[index];
    const cached = previous?.files[screenshot.path];
    const isUnchanged =
      cached?.size === screenshot.size && cached.modifiedAt === screenshot.modifiedAt;
    const text = isUnchanged ? cached.text : await extractText(screenshot.path);

    if (isUnchanged) {
      reused += 1;
    } else {
      indexed += 1;
    }

    files[screenshot.path] = {
      size: screenshot.size,
      modifiedAt: screenshot.modifiedAt,
      text,
    };
    indexedScreenshots.push({ ...screenshot, text });
    onProgress?.({
      completed: index + 1,
      total: screenshots.length,
      indexed,
      reused,
    });
  }

  await saveIndex({ version: 1, directory, files });

  return { screenshots: indexedScreenshots, indexed, reused };
}
