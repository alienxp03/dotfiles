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

## Local-Only Configuration Boundaries

Default bootstrap (`setup.sh`) only stows:

```bash
stow zsh tmux nvim terminal tools ruby
```

Treat files in these package directories as shared/tracked by default. Keep machine-specific or secret values in local-only files under `$HOME`:

- `~/.config/zsh/aliases.private.zsh`
- `~/.config/zsh/aliases.local.zsh`
- `~/.config/zsh/env.local.zsh`
- `~/.config/zsh/functions.local.zsh`

`~/.config/zsh/init.zsh` sources each of these files only if it exists. This repo ignores `*.local.zsh`, but does not ignore `aliases.private.zsh`, so keep `aliases.private.zsh` outside this repo or add a local Git exclude for `zsh/.config/zsh/aliases.private.zsh`.

Before committing, verify local-only files are still untracked:

```bash
git status --short --untracked-files=all
```

## Repository Hygiene

Remove Finder metadata files:

```bash
find . -name '.DS_Store' -delete
```

Resolve the stale tracked path if it appears in status:

```bash
git rm zshrc/alias.personal.zsh
```

Verify repository hygiene:

```bash
git ls-files | rg 'DS_Store$'
find . -name '.DS_Store'
git status --short
```
