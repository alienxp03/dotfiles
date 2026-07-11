#!/usr/bin/env bash
set -euo pipefail

# GUI-launched apps do not inherit the shell's Mise PATH on macOS.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Identify this window so Kitty can pass Ctrl+J/K through to fzf.
printf '\033]2;project-picker\007'

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '%s is required but was not found in PATH.\n' "$1" >&2
    exit 1
  }
}

require_cmd fzf
require_cmd jq
require_cmd zoxide

kitty_bin="$(command -v kitty || true)"
if [[ -z "$kitty_bin" && -x /Applications/kitty.app/Contents/MacOS/kitty ]]; then
  kitty_bin=/Applications/kitty.app/Contents/MacOS/kitty
fi
if [[ -z "$kitty_bin" ]]; then
  printf 'kitty was not found in PATH.\n' >&2
  exit 1
fi

kitty_socket="${KITTY_SOCKET:-}"
if [[ -z "$kitty_socket" ]]; then
  # Quick-access terminals create their own Kitty socket. Select only the
  # main Kitty process so sessions always open in the primary OS window.
  for socket_dir in /private/tmp /tmp "${TMPDIR:-}"; do
    [[ -n "$socket_dir" && -d "$socket_dir" ]] || continue
    while IFS= read -r socket_path; do
      pid="${socket_path##*-}"
      process="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      if [[ "$process" == "$kitty_bin"* ]]; then
        kitty_socket="unix:$socket_path"
        break 2
      fi
    done < <(find "$socket_dir" -maxdepth 1 -type s -name 'kitty-*' -print 2>/dev/null | sort)
  done
fi

kitty_at() {
  "$kitty_bin" @ --to "$kitty_socket" "$@"
}

kitty_state="$(kitty_at ls)" || {
  printf 'Unable to connect to Kitty at %s. Restart Kitty after enabling remote control.\n' "$kitty_socket" >&2
  exit 1
}

normalize_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
  fi
}

open_paths="$(printf '%s' "$kitty_state" | jq -r '
  [.[]?.tabs[]?.windows[]?
    | select(.session_name != null and .session_name != "")
    | {path: (.env.PWD // .cwd // ""), focused: (.last_focused_at // 0)}]
  | group_by(.path)[]
  | [.[0].path, (map(.focused) | max)]
  | @tsv
')"

# Open sessions come first in most-recently-focused order. Closed projects keep
# zoxide's frecency order, so recently/frequently used directories stay near the top.
menu_entries="$(awk -F '\t' -v OFS='\t' -v home="$HOME" '
  NR == FNR {
    if ($1 != "") open[$1] = $2
    next
  }
  {
    path = $0
    # A root-directory entry has no useful project/session label.
    if (path == "" || path == "/") next
    count = split(path, parts, "/")
    name = parts[count]
    display_path = path
    if (path == home) display_path = "~"
    else if (index(path, home "/") == 1) display_path = "~" substr(path, length(home) + 1)
    marker = (path in open) ? "●" : "○"
    rank = (path in open) ? 0 : 1
    score = (path in open) ? open[path] : -FNR
    # The first two fields are temporary sort keys and are removed afterward.
    print rank, score, path, marker " " sprintf("%-28s", name), display_path
  }
' <(printf '%s\n' "$open_paths") <(zoxide query -l) \
  | sort -t $'\t' -k1,1n -k2,2nr \
  | cut -f3-)"

selected="$(printf '%s\n' "$menu_entries" | fzf \
  --height=60% \
  --layout=reverse \
  --border \
  --prompt=' kitty session > ' \
  --header='SESSION                         DIRECTORY     ● open  ○ create  esc: cancel' \
  --with-nth=2,3 \
  --delimiter=$'\t' || true)"

[[ -n "$selected" ]] || exit 0
selected_path="$(normalize_path "${selected%%$'\t'*}")"

existing_session="$(printf '%s' "$kitty_state" | jq -r --arg path "$selected_path" '
  .[]?.tabs[]?.windows[]?
  | select(.session_name != null and .session_name != "")
  | select((.env.PWD // .cwd // "") as $cwd | $cwd == $path)
  | .session_name
' | head -n1)"

if [[ -n "$existing_session" ]]; then
  kitty_at action goto_session "$existing_session"
  exit 0
fi

session_dir="${TMPDIR:-/tmp}/kitty-zoxide-sessions"
mkdir -p "$session_dir"
base_name="$(printf '%s' "$(basename "$selected_path")" | tr -cs 'A-Za-z0-9._-' '_')"
if command -v shasum >/dev/null 2>&1; then
  hash="$(printf '%s' "$selected_path" | shasum -a 256 | cut -c1-6)"
elif command -v sha256sum >/dev/null 2>&1; then
  hash="$(printf '%s' "$selected_path" | sha256sum | cut -c1-6)"
else
  hash="$(printf '%s' "$selected_path" | cksum | cut -d' ' -f1)"
fi
session_name="$base_name"
# Only add a suffix when another project has the same directory name.
if printf '%s' "$kitty_state" | jq -e --arg name "$session_name" '
  any(.[]?.tabs[]?.windows[]?; .session_name == $name)
' >/dev/null; then
  session_name="${base_name}-${hash}"
fi
session_file="$session_dir/$session_name.kitty-session"

cat >"$session_file" <<EOF
layout splits
cd $selected_path
launch --title "$base_name"
focus
focus_os_window
EOF

kitty_at action goto_session "$session_file"
zoxide add -- "$selected_path" >/dev/null 2>&1 || true
