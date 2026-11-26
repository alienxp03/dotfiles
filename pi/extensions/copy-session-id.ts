import { copyToClipboard, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("copy-session-id", {
    description: "Copy the current Pi session ID to the clipboard",
    handler: async (_args, ctx) => {
      try {
        await copyToClipboard(ctx.sessionManager.getSessionId());
        ctx.ui.notify("Session ID copied to the clipboard", "info");
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Could not copy the session ID: ${message}`, "error");
      }
    },
  });
}
