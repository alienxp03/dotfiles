import { Clipboard, showToast, Toast } from "@raycast/api";
import {
  findScreenshots,
  removeExpiredScreenshots,
  screenshotsDirectory,
  type Screenshot,
} from "./screenshots";

export default async function PasteLastScreenshot() {
  const directory = screenshotsDirectory();
  let latest: Screenshot | undefined;

  try {
    await removeExpiredScreenshots(directory);
    [latest] = await findScreenshots(directory);
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not read screenshots",
      message: error instanceof Error ? error.message : String(error),
    });
    return;
  }

  if (!latest) {
    await showToast({
      style: Toast.Style.Failure,
      title: "No screenshot found",
      message: `No images found in ${directory}`,
    });
    return;
  }

  try {
    await Clipboard.paste({ file: latest.path });
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not paste screenshot",
      message: error instanceof Error ? error.message : String(error),
    });
  }
}
