# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# antidote zsh plugin manager
source /opt/homebrew/opt/antidote/share/antidote/antidote.zsh
antidote load

# Load completions
autoload -Uz compinit && compinit

# Themes
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# eval "$(starship init zsh)"

source "$HOME/.config/zsh/init.zsh"
eval "$(zoxide init zsh)"
eval "$($HOME/.local/bin/mise activate zsh)"
eval "$(atuin init zsh)"
source <(fzf --zsh)

. "$HOME/.atuin/bin/env"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/azuan/.lmstudio/bin"
# End of LM Studio CLI section


# bun completions
[ -s "/Users/azuan/.bun/_bun" ] && source "/Users/azuan/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/azuan/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
