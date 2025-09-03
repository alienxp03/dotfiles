# Dotfiles

My dotfiles. Hope it's useful for others. Primarily using it for:

1. Golang
2. Ruby on Rails
3. Web development in general
4. Lua
5. Docker
6. Terraform

## Stow Setup

This repo is organized into GNU Stow packages. Each package mirrors the target paths under `$HOME`.

- zsh: `zsh/.zshrc`, `zsh/.zsh_plugins.txt`, `zsh/.p10k.zsh`, `zsh/.config/zsh/*`
- tmux: `tmux/.tmux.conf`
- nvim: `nvim/.config/nvim/**`
- terminal: `.config/alacritty/alacritty.toml`, `.config/ghostty/config`
- tools: `.config/lazygit/config.yml`, `.tool-versions`
- ruby: `ruby/.irbrc`, `ruby/.pryrc`, `ruby/.solargraph.yml`, `ruby/.ruby-lsp/**`

### Usage

Dry-run to preview symlinks:

```
stow -nv zsh tmux nvim terminal tools ruby
```

Apply:

```
stow -v zsh tmux nvim terminal tools ruby
```

Adopt existing files in `$HOME` (moves them into the package):

```
stow --adopt zsh tmux nvim terminal tools ruby
```

Unstow:

```
stow -D zsh tmux nvim terminal tools ruby
```

Notes:
- zsh sources configs from `~/.config/zsh`. Optionally place private aliases at `~/.config/zsh/aliases.private.zsh` (not tracked here).
- Alacritty, Ghostty, and Lazygit use XDG config paths under `~/.config`.
- `personal/` is a separate repo/submodule and not stowed by default.
