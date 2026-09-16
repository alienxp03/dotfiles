import { environment } from "@raycast/api";
import { execFile } from "node:child_process";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const OCR_HELPER = "screenshot-ocr";

export async function extractText(imagePath: string): Promise<string> {
  const { stdout } = await execFileAsync(
    join(environment.assetsPath, OCR_HELPER),
    [imagePath],
    { maxBuffer: 4 * 1024 * 1024 },
  );

  return stdout.trim();
}
