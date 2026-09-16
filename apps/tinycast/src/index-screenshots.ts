import { showToast, Toast } from "@raycast/api";
import { indexScreenshots } from "./screenshot-index";
import { screenshotsDirectory } from "./screenshots";

export default async function IndexScreenshots() {
  const directory = screenshotsDirectory();
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Indexing screenshots",
  });

  try {
    const result = await indexScreenshots(directory, ({ completed, total }) => {
      toast.message = `${completed} of ${total}`;
    });

    toast.style = Toast.Style.Success;
    toast.title = "Screenshots indexed";
    toast.message = `${result.indexed} OCR'd, ${result.reused} reused`;
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Could not index screenshots";
    toast.message = error instanceof Error ? error.message : String(error);
  }
}
