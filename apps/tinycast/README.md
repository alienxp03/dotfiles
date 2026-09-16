# Screenshot Manager for Tinycast

Raycast-compatible extension for Tinycast.

## Commands

- **View Screenshots** — displays image files from the configured directory as a preview grid and searches OCR text.
- **Index Screenshots** — extracts and caches text from new or changed images.
- **Delete Old Screenshots** — permanently deletes images older than the configured retention period.
- **Paste Last Screenshot** — pastes the newest image file into the focused app.

The directory defaults to `~/Desktop` and can be changed under **Tinycast Settings → Extensions → Screenshot Manager → Configure**.

Configure each command's global shortcut in its command row under **Tinycast Settings → Extensions**.

> **Paste permission:** Tinycast must be enabled in **System Settings → Privacy & Security → Accessibility**. Its extension bridge can report success after writing the pasteboard even when macOS blocks the synthetic `⌘V`, so a missing permission looks like a successful no-op.

## Build and run

Run **Index Screenshots** once after installing, then again when you want to refresh OCR for new or changed images. The index is stored in Tinycast's extension-local storage; image files are not copied.

Set **Screenshot retention** to Unlimited, 3, 6, or 12 months in the extension settings. Run **Delete Old Screenshots** to permanently remove screenshots older than that period; Unlimited is the default and never deletes anything.

Build it from anywhere with one command:

```sh
cd ~/.dotfiles/apps/tinycast && npm install && npm run build
```

Then open **Tinycast Settings → Extensions → Install → Local folder**, select
`~/.dotfiles/apps/tinycast`, and enable the extension. Rebuild and reinstall after
source changes; Tinycast copies the built extension into its own app data.

To remove the previously installed copy, use **Tinycast Settings → Extensions →
Uninstall Extension** before reinstalling it from this location.
