#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_PAT:?GITHUB_PAT is required}"
: "${GITHUB_USER:?GITHUB_USER is required}"
: "${GITHUB_EMAIL:?GITHUB_EMAIL is required}"
: "${DOTFILES_REPO:?DOTFILES_REPO is required}"
DOTFILES_DIR=".dotfiles"
DOTFILES_PATH="$HOME/$DOTFILES_DIR"
MISE_CONFIG_PATH=""

log() {
  printf '\n==> %s\n' "$*"
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'error: need root privileges for: %s\n' "$*" >&2
    exit 1
  fi
}

git_with_github_pat() {
  # GITHUB_USER/GITHUB_PAT are expanded by git's credential-helper shell, not here.
  # shellcheck disable=SC2016
  GIT_TERMINAL_PROMPT=0 git \
    -c credential.helper='!f() { echo username="$GITHUB_USER"; echo password="$GITHUB_PAT"; }; f' \
    "$@"
}

install_base_packages() {
  log "Installing base packages"

  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y ca-certificates curl git make sudo zsh build-essential
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y ca-certificates curl git make sudo zsh gcc gcc-c++
  elif command -v apk >/dev/null 2>&1; then
    run_as_root apk add --no-cache ca-certificates curl git make sudo zsh build-base bash
  elif command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -Sy --needed --noconfirm ca-certificates curl git make sudo zsh base-devel
  else
    printf 'error: unsupported Linux package manager; install curl, git, make, sudo, and zsh manually\n' >&2
    exit 1
  fi
}

install_mise() {
  if command -v mise >/dev/null 2>&1; then
    log "mise already installed"
    return
  fi

  log "Installing mise"
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v mise >/dev/null 2>&1; then
    printf 'error: mise install completed but mise is not on PATH\n' >&2
    exit 1
  fi
}

setup_git_identity() {
  log "Setting Git identity"
  git config --global user.name "$GITHUB_USER"
  git config --global user.email "$GITHUB_EMAIL"
}

setup_default_shell() {
  log "Setting default shell"

  zsh_path="$(command -v zsh)"

  if ! grep -qx "$zsh_path" /etc/shells; then
    printf '%s\n' "$zsh_path" | run_as_root tee -a /etc/shells >/dev/null
  fi

  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [ "$current_shell" != "$zsh_path" ]; then
    run_as_root chsh -s "$zsh_path" "$USER"
  fi
}

clone_or_update_dotfiles() {
  log "Cloning/updating dotfiles"

  if [ -d "$DOTFILES_PATH/.git" ]; then
    git -C "$DOTFILES_PATH" remote set-url origin "$DOTFILES_REPO"
    git_with_github_pat -C "$DOTFILES_PATH" pull --ff-only
  elif [ -e "$DOTFILES_PATH" ]; then
    printf 'error: %s exists but is not a git repository\n' "$DOTFILES_PATH" >&2
    exit 1
  else
    git_with_github_pat clone "$DOTFILES_REPO" "$DOTFILES_PATH"
  fi
}

prepare_mise_config() {
  log "Preparing mise config"

  if [ -f "$DOTFILES_PATH/config/mise/config.toml" ]; then
    MISE_CONFIG_PATH="$DOTFILES_PATH/config/mise/config.toml"
  elif [ -f "$DOTFILES_PATH/dotfiles/config/mise/config.toml" ]; then
    MISE_CONFIG_PATH="$DOTFILES_PATH/dotfiles/config/mise/config.toml"
  else
    printf 'error: unable to find dotfiles mise config under %s\n' "$DOTFILES_PATH" >&2
    exit 1
  fi

  mkdir -p "$HOME/.config/mise"

  if [ -L "$HOME/.config/mise/config.toml" ] && [ "$(readlink "$HOME/.config/mise/config.toml")" = "$MISE_CONFIG_PATH" ]; then
    return
  fi

  if [ -e "$HOME/.config/mise/config.toml" ] || [ -L "$HOME/.config/mise/config.toml" ]; then
    mv "$HOME/.config/mise/config.toml" "$HOME/.config/mise/config.toml.bootstrap-backup.$(date +%Y%m%d%H%M%S)"
  fi

  ln -s "$MISE_CONFIG_PATH" "$HOME/.config/mise/config.toml"
}

run_dotfiles_setup() {
  log "Running dotfiles setup"
  cd "$DOTFILES_PATH"

  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  GITHUB_TOKEN="$GITHUB_PAT" MISE_EXPERIMENTAL=1 mise install
  GITHUB_TOKEN="$GITHUB_PAT" MISE_EXPERIMENTAL=1 mise dotfiles apply --force --yes
}

install_base_packages
install_mise
setup_git_identity
setup_default_shell
clone_or_update_dotfiles
prepare_mise_config
run_dotfiles_setup

log "Linux setup complete"
