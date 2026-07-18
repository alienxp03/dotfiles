#!/usr/bin/env bash
set -euo pipefail

# GUI-launched apps do not inherit the shell's Mise PATH on macOS.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Identify the interactive window so Kitty can pass Ctrl+J/K through to fzf.
if [[ "${1:-}" != "--menu-only" ]]; then
  printf '\033]2;project-picker\007'
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kitty"
menu_cache="$cache_dir/session-picker.tsv"
fzf_options=(
  "--height=60%"
  "--layout=reverse"
  "--scheme=history"
  "--border"
  "--prompt= kitty sessions > "
  "--header=SESSION                         DIRECTORY     ⚡ SSH host  ● open  ○ create  esc: cancel"
  "--with-nth=2,3"
  $'--delimiter=\t'
)

# Keep the visible path minimal: show cached entries before resolving the
# Kitty socket. The reload subprocess refreshes state while fzf is already up.
if [[ -z "${1:-}" && "${KITTY_PICKER_CACHE:-0}" == "1" && -s "$menu_cache" ]]; then
  fzf_options+=("--bind=start:reload:$script_dir/kitty-zoxide-session.sh --menu-only")
  selected="$(fzf "${fzf_options[@]}" <"$menu_cache" || true)"
  [[ -n "$selected" ]] || exit 0
  exec "$script_dir/kitty-zoxide-session.sh" --select "$selected"
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '%s is required but was not found in PATH.\n' "$1" >&2
    exit 1
  }
}

require_cmd fzf
require_cmd python3
require_cmd zoxide

kitty_bin="$(command -v kitty || true)"
if [[ -z "$kitty_bin" && -x /Applications/kitty.app/Contents/MacOS/kitty ]]; then
  kitty_bin=/Applications/kitty.app/Contents/MacOS/kitty
fi
if [[ -z "$kitty_bin" ]]; then
  printf 'kitty was not found in PATH.\n' >&2
  exit 1
fi

kitty_socket="${KITTY_SOCKET:-${KITTY_LISTEN_ON:-}}"
socket_cache="${TMPDIR:-/tmp}/kitty-zoxide.socket"
if [[ -z "$kitty_socket" && -r "$socket_cache" ]]; then
  cached_socket="$(<"$socket_cache")"
  if [[ "$cached_socket" == unix:* && -S "${cached_socket#unix:}" ]]; then
    kitty_socket="$cached_socket"
  fi
fi
if [[ -z "$kitty_socket" ]]; then
  # Fall back to finding the main Kitty process when no socket was inherited.
  for socket_dir in /private/tmp /tmp "${TMPDIR:-}"; do
    [[ -n "$socket_dir" && -d "$socket_dir" ]] || continue
    while IFS= read -r socket_path; do
      pid="${socket_path##*-}"
      process="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      if [[ "$process" == "$kitty_bin"* ]]; then
        kitty_socket="unix:$socket_path"
        printf '%s\n' "$kitty_socket" >"$socket_cache"
        break 2
      fi
    done < <(find "$socket_dir" -maxdepth 1 -type s -name 'kitty-*' -print 2>/dev/null | sort)
  done
fi

kitty_at() {
  "$kitty_bin" @ --to "$kitty_socket" "$@"
}

normalize_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
  fi
}

build_menu() {
  "$script_dir/kitty-session-menu.py" "$kitty_bin" "$kitty_socket" "$HOME"
}
refresh_cache() {
  local temporary
  mkdir -p "$cache_dir"
  temporary="$menu_cache.$$"
  if build_menu >"$temporary"; then
    mv -f "$temporary" "$menu_cache"
  else
    rm -f "$temporary"
    return 1
  fi
}

if [[ "${1:-}" == "--menu-only" ]]; then
  refresh_cache
  exec cat "$menu_cache"
fi

if [[ "${1:-}" == "--select" ]]; then
  selected="${2:-}"
else
  menu_entries="$(build_menu)" || {
    printf 'Unable to build the Kitty session menu using %s.\n' "$kitty_socket" >&2
    exit 1
  }
  if [[ "${KITTY_PICKER_CACHE:-0}" == "1" ]]; then
    mkdir -p "$cache_dir"
    printf '%s\n' "$menu_entries" >"$menu_cache"
  fi
  selected="$(printf '%s\n' "$menu_entries" | fzf "${fzf_options[@]}" || true)"
fi

[[ -n "$selected" ]] || exit 0
selected_key="${selected%%$'\t'*}"
selected_tail="${selected#*$'\t'}"
selected_tail="${selected_tail#*$'\t'}"
selected_tail="${selected_tail#*$'\t'}"
existing_session="${selected_tail%%$'\t'*}"
name_taken="${selected_tail#*$'\t'}"

if [[ "$selected_key" == ssh://* ]]; then
  ssh_host="${selected_key#ssh://}"
  session_dir="${TMPDIR:-/tmp}/kitty-zoxide-sessions"
  mkdir -p "$session_dir"
  safe_host="$(printf '%s' "$ssh_host" | tr -cs 'A-Za-z0-9._-' '_')"
  ssh_session_file="$session_dir/ssh-$safe_host.kitty-session"
  if [[ "$existing_session" != "-" ]]; then
    kitty_at action goto_session "$existing_session"
    exit 0
  fi

  cat >"$ssh_session_file" <<EOF
layout splits
cd $HOME
launch --title "ssh: $ssh_host" ssh "$ssh_host"
focus
focus_os_window
EOF

  kitty_at action goto_session "$ssh_session_file"
  exit 0
fi

selected_path="$(normalize_path "$selected_key")"

if [[ "$existing_session" != "-" ]]; then
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
if [[ "$name_taken" == "1" ]]; then
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
