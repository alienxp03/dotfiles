import { Grid, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { indexScreenshots, type IndexedScreenshot } from "./screenshot-index";
import { removeExpiredScreenshots, screenshotsDirectory } from "./screenshots";

export default function ViewScreenshots() {
  const [screenshots, setScreenshots] = useState<IndexedScreenshot[]>([]);
  const [errorMessage, setErrorMessage] = useState<string>();
  const [isLoading, setIsLoading] = useState(true);
  const directory = screenshotsDirectory();

  useEffect(() => {
    let isCurrent = true;

    setIsLoading(true);
    setErrorMessage(undefined);
    async function loadScreenshots() {
      try {
        await removeExpiredScreenshots(directory);
        const result = await indexScreenshots(directory);
        if (isCurrent) {
          setScreenshots(result.screenshots);
        }
      } catch (error) {
        if (!isCurrent) {
          return;
        }

        const message = error instanceof Error ? error.message : String(error);
        setScreenshots([]);
        setErrorMessage(message);
        await showToast({
          style: Toast.Style.Failure,
          title: "Could not read screenshots",
          message,
        });
      } finally {
        if (isCurrent) {
          setIsLoading(false);
        }
      }
    }

    void loadScreenshots();

    return () => {
      isCurrent = false;
    };
  }, [directory]);

  return (
    <Grid
      columns={4}
      fit={Grid.Fit.Contain}
      aspectRatio="16/9"
      isLoading={isLoading}
      searchBarPlaceholder="Search screenshots..."
      navigationTitle="Screenshots"
    >
      {screenshots.map((screenshot) => (
        <Grid.Item
          key={screenshot.path}
          title={screenshot.name}
          keywords={screenshot.text ? [screenshot.text] : undefined}
          content={{ source: screenshot.path }}
        />
      ))}
      {!isLoading && screenshots.length === 0 && (
        <Grid.EmptyView
          title={errorMessage ? "Could not read screenshots" : "No screenshots found"}
          description={errorMessage ?? `No images found in ${directory}`}
        />
      )}
    </Grid>
  );
}
