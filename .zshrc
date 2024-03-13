# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

unsetopt INTERACTIVE_COMMENTS
unsetopt BAD_PATTERN

source "$HOME/.dotfiles/zshrc/env.zsh"
# For cross-platform logics
if [ "$(uname -s)" = "Darwin" ]; then
  source "$HOME/.dotfiles/zshrc/env.darwin.zsh"
elif [ "$(uname -s)" = "Linux" ]; then
  source "$HOME/.dotfiles/zshrc/env.linux.zsh"
fi
source "$HOME/.dotfiles/zshrc/env.local.zsh"

plugins=(zsh-autosuggestions tmux zsh-fzf-history-search asdf fzf-tab forgit)
source $ZSH/oh-my-zsh.sh

source "$HOME/.dotfiles/zshrc/aliases.zsh"
source "$HOME/.dotfiles/zshrc/aliases.local.zsh"
source "$HOME/.dotfiles/zshrc/functions.zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/azuan.zairein/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
