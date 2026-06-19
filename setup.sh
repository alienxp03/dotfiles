#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Stow all dotfile packages
packages=(
  atuin
  bin
  claude
  config
  hammerspoon
  karabiner
  mise
  nvim
  opencode
  ruby
  terminal
  tmux
  tools
  zsh
)

stow "${packages[@]}"

# Ghostty uses a non-standard config path on macOS
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
ln -sf ~/.dotfiles/terminal/.config/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config

echo "Dotfiles synced!"
