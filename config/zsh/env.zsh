export WORKSPACE="$HOME/Workspace"
export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="powerlevel10k/powerlevel10k"
export EDITOR='nvim'
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
export LIBGL_ALWAYS_SOFTWARE=1
export TMUXIFIER_LAYOUT_PATH="$HOME/.tmux-layouts"
export DOCKER_BUILDKIT=1
export DOTFILES=~/.dotfiles
export SOLARGRAPH_GLOBAL_CONFIG=~/.solargraph.yml
export ZAI_BASE_URL="https://api.z.ai/api/anthropic"
export ZAI_MODEL="glm-5.2"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$WORKSPACE/bin/apache-maven-3.8.6/bin:$PATH"
export PATH="$WORKSPACE/bin/AssetRipperConsole_linux64:$PATH"
export PATH="$WORKSPACE/bin/:$PATH"
export PATH="$WORKSPACE/bin/apache-maven/bin/:$PATH"
export PATH="/usr/local/bin/:$PATH"
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
export PATH="$HOME/.tmux/plugins/tmuxifier/bin:$PATH"
export PATH="$HOME/.tmux/plugins/t-smart-tmux-session-manager/bin:$PATH"
export PATH="$WORKSPACE/GitHub/diff-so-fancy:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

# Golang
export CGO_CFLAGS=-Wno-undef-prefix

# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_CMDLINE_TOOLS_HOME="$ANDROID_HOME/cmdline-tools/latest"

export PATH="$ANDROID_CMDLINE_TOOLS_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# golang
# export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOPROXY=direct
export PATH="$PATH:$GOROOT/bin"
export PATH="$PATH:$GOPATH/bin"

# zsh-vi-mode
export ZVM_VI_EDITOR="nvim"
export ZVM_SYSTEM_CLIPBOARD_ENABLED=true
export ZVM_INIT_MODE=sourcing

# forgit
export PATH="$PATH:$FORGIT_INSTALL_DIR/bin"
export FORGIT_NO_ALIASES=1

export PATH="$HOME/.rd/bin:$PATH"

export PATH="$PATH:$HOME/.lmstudio/bin"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section

export CODEX_HOME=$HOME/.codex

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
