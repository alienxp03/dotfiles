#!/bin/bash
# Stow all dotfile packages
stow zsh tmux nvim terminal tools ruby

# Ghostty uses a non-standard config path on macOS
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
ln -sf ~/.dotfiles/terminal/.config/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config

echo "Dotfiles synced!"
