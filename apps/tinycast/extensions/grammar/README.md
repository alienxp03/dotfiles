# Grammar for Tinycast

Copy text in any app, then run **Grammar** to immediately generate a configurable number of Pi or Codex alternatives. Answers appear directly in a list. Press Enter to copy the selected answer and paste it into the previous app. If paste fails, the answer stays on the clipboard for manual paste. Use **Copy Answer** to copy without pasting.

## Requirements

- Tinycast with Raycast-compatible extensions enabled.
- Pi or Codex CLI installed and signed in. Pi uses its `openai-codex` login; Codex uses `codex login`. No API key is stored by this extension.

The clipboard text and prompt are sent to the selected provider. Pi runs without tools or session persistence; Codex runs ephemerally with a read-only sandbox. Both use a fresh empty working directory.

## Build

```sh
cd ~/.dotfiles/apps/tinycast/extensions/grammar
npm install
npm run lint
npm run build
```

In Tinycast, install the local folder from **Settings → Extensions → Install → Local folder** and select this directory. Choose Pi or Codex and configure its CLI path, answer count, initial prompt, model and reasoning effort in the extension settings. Pi is the default backend. Defaults are three answers, `gpt-6-sol` and `low`; models are `gpt-6-astra`, `gpt-6-sol`, `gpt-6-luna`, and efforts are `low`, `medium`, `high`, `xhigh`. The prompt is set in extension preferences. CLI paths default to the mise shims at `~/.local/share/mise/shims/pi` and `~/.local/share/mise/shims/codex`.
