import { Alert, confirmAlert, showToast, Toast } from "@raycast/api";
import { unlink } from "node:fs/promises";
import {
  findScreenshots,
  retentionCutoff,
  screenshotRetentionPeriod,
  screenshotsDirectory,
  type RetentionPeriod,
} from "./screenshots";

const RETENTION_LABELS: Record<RetentionPeriod, string> = {
  unlimited: "Unlimited",
  "3-months": "3 months",
  "6-months": "6 months",
  "12-months": "12 months",
};

export default async function DeleteOldScreenshots() {
  const directory = screenshotsDirectory();
  const period = screenshotRetentionPeriod();
  const cutoff = retentionCutoff(period);

  if (cutoff === undefined) {
    await showToast({
      style: Toast.Style.Success,
      title: "Screenshot retention is unlimited",
      message: "Choose a retention period in the extension settings first.",
    });
    return;
  }

  let screenshots;
  try {
    screenshots = await findScreenshots(directory);
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not read screenshots",
      message: error instanceof Error ? error.message : String(error),
    });
    return;
  }

  const oldScreenshots = screenshots.filter(
    (screenshot) => screenshot.modifiedAt < cutoff,
  );

  if (oldScreenshots.length === 0) {
    await showToast({
      style: Toast.Style.Success,
      title: "No old screenshots found",
      message: `Nothing older than ${RETENTION_LABELS[period]}.`,
    });
    return;
  }

  const confirmed = await confirmAlert({
    title: `Delete ${oldScreenshots.length} old screenshot${oldScreenshots.length === 1 ? "" : "s"}?`,
    message: `This will permanently delete images older than ${RETENTION_LABELS[period]}.`,
    primaryAction: {
      title: "Delete",
      style: Alert.ActionStyle.Destructive,
    },
  });

  if (!confirmed) {
    return;
  }

  let deleted = 0;
  let failed = 0;
  for (const screenshot of oldScreenshots) {
    try {
      await unlink(screenshot.path);
      deleted += 1;
    } catch {
      failed += 1;
    }
  }

  await showToast({
    style: failed === 0 ? Toast.Style.Success : Toast.Style.Failure,
    title: failed === 0 ? "Old screenshots deleted" : "Some screenshots could not be deleted",
    message: `${deleted} deleted${failed > 0 ? `, ${failed} failed` : ""}.`,
  });
}
