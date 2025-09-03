source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/aliases.private.zsh" ]] && source "$HOME/.config/zsh/aliases.private.zsh"
[[ -f "$HOME/.config/zsh/aliases.local.zsh" ]] && source "$HOME/.config/zsh/aliases.local.zsh"
source "$HOME/.config/zsh/functions.zsh"
source "$HOME/.config/zsh/env.zsh"

# For cross-platform logics
if [ "$(uname -s)" = "Darwin" ]; then
  source "$HOME/.config/zsh/env.darwin.zsh"
elif [ "$(uname -s)" = "Linux" ]; then
  source "$HOME/.config/zsh/env.linux.zsh"
fi

[[ -f "$HOME/.config/zsh/env.local.zsh" ]] && source "$HOME/.config/zsh/env.local.zsh"

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
