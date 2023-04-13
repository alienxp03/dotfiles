export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="powerlevel10k/powerlevel10k"
export EDITOR='nvim'
export PATH="$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export RUBY_CONFIGURE_OPTSx="--with-openssl-dir=/opt/openssl-1.1.1s/"
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
export LIBGL_ALWAYS_SOFTWARE=1
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
export PATH="$WORKSPACE/bin/apache-maven-3.8.6/bin:$PATH"
export PATH="$WORKSPACE/bin/AssetRipperConsole_linux64:$PATH"
export PATH="$WORKSPACE/bin/:$PATH"
export DOCKER_BUILDKIT=1

# golang
export GOROOT="/usr/local/go"
export PATH="$PATH:$GOROOT/bin"
export GOPATH="$WORKSPACE/go"
export PATH="$PATH:$GOPATH/bin"

# FZF fuzzy search
export FZF_DEFAULT_COMMAND="rg --files --follow --no-ignore-vcs --hidden -g '!{**/node_modules/*,**/.git/*,**/tmp/*}'"

# . $HOME/.asdf/asdf.sh

eval "$(zoxide init zsh)"
eval "$(rbenv init - zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

