export PATH="$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$WORKSPACE/bin/apache-maven-3.8.6/bin:$PATH"
export PATH="$WORKSPACE/bin/AssetRipperConsole_linux64:$PATH"
export PATH="$WORKSPACE/bin/:$PATH"
export PATH="/usr/local/bin/:$PATH"
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
export PATH="$HOME/.tmux/plugins/tmuxifier/bin:$PATH"
export PATH="$HOME/.tmux/plugins/t-smart-tmux-session-manager/bin:$PATH"
export PATH="$WORKSPACE/GitHub/diff-so-fancy:$PATH"

export WORKSPACE="$HOME/Workspace"
export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="powerlevel10k/powerlevel10k"
export EDITOR='nvim'
export RUBY_CONFIGURE_OPTSx="--with-openssl-dir=/opt/openssl-1.1.1s/"
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
export LIBGL_ALWAYS_SOFTWARE=1
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
export TMUXIFIER_LAYOUT_PATH="$HOME/.tmux-layouts"
export DOCKER_BUILDKIT=1
export DOTFILES=~/.dotfiles
export SOLARGRAPH_GLOBAL_CONFIG=~/.solargraph.yml

# Golang
export CGO_CFLAGS=-Wno-undef-prefix

# golang
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$PATH:$GOROOT/bin"
export PATH="$PATH:$GOPATH/bin"

# forgit
export PATH="$PATH:$FORGIT_INSTALL_DIR/bin"
export FORGIT_NO_ALIASES=1

export ASDF_DIR="$HOME/.asdf"
. "$HOME/.asdf/asdf.sh"
. ~/.asdf/plugins/golang/set-env.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

eval "$(zoxide init zsh)"
eval "$(rbenv init - zsh)"