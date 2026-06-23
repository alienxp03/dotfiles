# Dotfiles

My dotfiles. Hope it's useful for others. Primarily using it for:

1. Golang
2. Ruby on Rails
3. Web development in general
4. Lua
5. Docker
6. Terraform

## Layout

This repo is managed by mise dotfiles instead of GNU Stow.

```text
home/          # files linked directly into $HOME
config/        # XDG config directories linked under ~/.config
local/bin/     # user executables linked under ~/.local/bin
macos/         # macOS-specific app config
```

Key examples:

- `home/.zshrc` -> `~/.zshrc`
- `config/zsh` -> `~/.config/zsh`
- `config/nvim` -> `~/.config/nvim`
- `config/mise/config.toml` -> `~/.config/mise/config.toml`
- `local/bin/dev-update` -> `~/.local/bin/dev-update`
- `macos/hammerspoon` -> `~/.hammerspoon`

The full mapping is declared in `config/mise/config.toml` under `[dotfiles]`.

## Usage

Preview dotfile changes:

```bash
MISE_GLOBAL_CONFIG_FILE="$PWD/config/mise/config.toml" mise dotfiles apply --dry-run --force --yes
```

Apply dotfiles:

```bash
make setup
```

Check status:

```bash
MISE_GLOBAL_CONFIG_FILE="$PWD/config/mise/config.toml" mise dotfiles status
```

Run validation:

```bash
make test
# or
MISE_GLOBAL_CONFIG_FILE="$PWD/config/mise/config.toml" mise test
```

Update mise-managed tools:

```bash
make update
```

Update the full development environment:

```bash
make dev-update
# or
MISE_GLOBAL_CONFIG_FILE="$PWD/config/mise/config.toml" mise run dev-update
```

## Local-Only Configuration Boundaries

Treat files under `home/`, `config/`, `local/`, and `macos/` as shared/tracked by default. Keep machine-specific or secret values in local-only files under `$HOME`:

- `~/.config/zsh/aliases.private.zsh`
- `~/.config/zsh/aliases.local.zsh`
- `~/.config/zsh/env.local.zsh`
- `~/.config/zsh/functions.local.zsh`

`~/.config/zsh/init.zsh` sources each of these files only if it exists. This repo ignores `*.local.zsh`, but does not ignore `aliases.private.zsh`, so keep `aliases.private.zsh` outside this repo or add a local Git exclude for `config/zsh/aliases.private.zsh`.

Before committing, verify local-only files are still untracked:

```bash
git status --short --untracked-files=all
```

## Repository Hygiene

Remove Finder metadata files:

```bash
find . -name '.DS_Store' -delete
```

Verify repository hygiene:

```bash
git ls-files | rg 'DS_Store$'
find . -name '.DS_Store'
git status --short
```
