#!/usr/bin/env bash
set -euo pipefail

# GUI-launched Kitty does not inherit the shell's full PATH on macOS.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Preserve the agent's foreground colors (including diff red/green), but remove
# its full-screen background so it does not obscure fzf's preview pane.
if [[ "${1:-}" == "--preview" ]]; then
  window_id="${2:?missing Kitty window ID}"
  kitty @ --to "$KITTY_LISTEN_ON" get-text --match "id:$window_id" --extent screen --ansi 2>&1 |
    python3 -c '
import re
import sys

ansi = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")
background = re.compile(rb"\x1b\[(?:48(?::[0-9]*)+|48(?:;[0-9]*)+|49)m")
lines = background.sub(b"", sys.stdin.buffer.read()).splitlines()
while lines and not ansi.sub(b"", lines[-1]).strip():
    lines.pop()
sys.stdout.buffer.write(b"\n".join(lines) + (b"\n" if lines else b""))
'
  exit 0
fi

# Match the project picker title so Kitty passes Ctrl+J/K through to fzf.
printf '\033]2;project-picker\007'

for command in kitty jq fzf python3; do
  command -v "$command" >/dev/null 2>&1 || {
    printf '%s is required but was not found in PATH.\n' "$command" >&2
    exit 1
  }
done

agents="$(kitty @ ls | jq -r '
  def agent_name:
    (.cmdline // [] | map(tostring) | join(" ")) as $command
    | if ($command | test("(^|[/ ])codex([ /]|$)"; "i")) then "codex"
      elif ($command | test("(^|[/ ])pi([ /]|$)"; "i")) then "pi"
      elif ($command | test("(^|[/ ])claude([ /]|$)"; "i")) then "claude"
      elif ($command | test("(^|[/ ])opencode([ /]|$)"; "i")) then "opencode"
      else "" end;

  .[]?.tabs[] as $tab
  | $tab.windows[]? as $window
  | [$window.foreground_processes[]?
      | . + {agent: agent_name}
      | select(.agent != "")][0]? as $process
  | select($process != null)
  | [
      ($window.id | tostring),
      $process.agent,
      (($window.cwd // $window.env.PWD // "")
        | if . == $ENV.HOME then "~"
          elif startswith($ENV.HOME + "/") then "~/" + ltrimstr($ENV.HOME + "/")
          else . end),
      ($tab.title // ""),
      ($process.cmdline | join(" "))
    ]
  | @tsv
')"

if [[ -z "$agents" ]]; then
  printf 'No running agents found.\n'
  sleep 1
  exit 0
fi

selected="$(printf '%s\n' "$agents" | fzf \
  --height=100% \
  --layout=reverse \
  --border \
  --prompt=' coding agents > ' \
  --header='AGENT  DIRECTORY  TAB     enter: focus  esc: cancel' \
  --delimiter=$'\t' \
  --with-nth=2,3,4 \
  --preview="$script_path --preview {1}" \
  --preview-window='right,65%,wrap,follow' \
  --preview-label=' agent screen ' || true)"

[[ -n "$selected" ]] || exit 0
window_id="${selected%%$'\t'*}"
kitty @ focus-window --match "id:$window_id"
