source "$HOME/.dotfiles/zshrc/aliases.zsh"
source "$HOME/.dotfiles/zshrc/aliases.local.zsh"
source "$HOME/.dotfiles/zshrc/functions.zsh"
source "$HOME/.dotfiles/zshrc/env.zsh"

# For cross-platform logics
# if [ "$(uname -s)" = "Darwin" ]; then
#   source "$HOME/.dotfiles/zshrc/env.darwin.zsh"
# elif [ "$(uname -s)" = "Linux" ]; then
#   source "$HOME/.dotfiles/zshrc/env.linux.zsh"
# fi

source "$HOME/.dotfiles/zshrc/env.local.zsh"

# custom mise prompt helper
# [[ -f ~/.p10k.mise.zsh ]] && source ~/.p10k.mise.zsh
# eval "$(starship init zsh)"

# History
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z} r:|[._-]=* l:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

