#!/bin/sh
set -eu

target_id=${KITTY_WINDOW_ID:-}
if [ -z "$target_id" ]; then
  target_id=$(kitty @ ls | jq -r '
    .[] | select(.is_focused)
    | .tabs[] | select(.is_active)
    | .windows[] | select(.is_focused)
    | .id
  ' | head -n 1)
fi

[ -n "$target_id" ] || exit 1

state_file="${TMPDIR:-/tmp}/kitty-tall-${target_id}"

if [ -e "$state_file" ]; then
  kitty @ resize-window --match "id:${target_id}" --axis reset
  rm -f "$state_file"
else
  kitty @ resize-window --match "id:${target_id}" --axis vertical --increment 100
  : >"$state_file"
fi
