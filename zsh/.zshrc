# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZVM_INIT_MODE=sourcing

# --- Immediate: source plugins inline (skip antidote runtime) ---
_ap="$HOME/Library/Caches/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-"

# powerlevel10k (needed for prompt)
fpath+=( "${_ap}romkatv-SLASH-powerlevel10k" )
source "${_ap}romkatv-SLASH-powerlevel10k/powerlevel10k.zsh-theme"
source "${_ap}romkatv-SLASH-powerlevel10k/powerlevel9k.zsh-theme"

# zsh-completions (just fpath, near-zero cost)
fpath+=( "${_ap}zsh-users-SLASH-zsh-completions" )
source "${_ap}zsh-users-SLASH-zsh-completions/zsh-completions.plugin.zsh"

# zsh-autosuggestions (needed immediately for typing)
fpath+=( "${_ap}zsh-users-SLASH-zsh-autosuggestions" )
source "${_ap}zsh-users-SLASH-zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"

# Load completions — skip security check if dump is from today
autoload -Uz compinit
if [[ ~/.zcompdump(#qNmh-24) ]]; then
  compinit -C
else
  compinit
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Cache eval output — regenerates when binary changes
_cached_source() {
  local cache=~/.cache/zsh/$1.zsh bin=$2
  shift 2
  if [[ ! -f $cache || $bin -nt $cache ]]; then
    "$@" > $cache 2>/dev/null
    zcompile $cache 2>/dev/null
  fi
  source $cache
}

# mise — load definitions only, defer the hook-env subprocess
export MISE_ACTIVATE_AGGRESSIVE=1
if [[ ! -f ~/.cache/zsh/mise_fast.zsh || ~/.local/bin/mise -nt ~/.cache/zsh/mise_fast.zsh ]]; then
  ~/.local/bin/mise activate zsh | sed '/_mise_hook$/d' > ~/.cache/zsh/mise_fast.zsh
  zcompile ~/.cache/zsh/mise_fast.zsh 2>/dev/null
fi
source ~/.cache/zsh/mise_fast.zsh

source "$HOME/.config/zsh/init.zsh"
_cached_source zoxide /opt/homebrew/bin/zoxide zoxide init zsh
_cached_source fzf /opt/homebrew/bin/fzf fzf --zsh

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/azuan.zairein/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# --- Deferred: loaded after first prompt renders ---
_zsh_deferred_init() {
  # Heavy plugins
  fpath+=( "${_ap}Aloxaf-SLASH-fzf-tab" )
  source "${_ap}Aloxaf-SLASH-fzf-tab/fzf-tab.plugin.zsh"
  fpath+=( "${_ap}jeffreytse-SLASH-zsh-vi-mode" )
  source "${_ap}jeffreytse-SLASH-zsh-vi-mode/zsh-vi-mode.plugin.zsh"
  fpath+=( "${_ap}zsh-users-SLASH-zsh-syntax-highlighting" )
  source "${_ap}zsh-users-SLASH-zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"

  # atuin shell history
  _cached_source atuin /opt/homebrew/bin/atuin atuin init zsh

  # kubectl completions
  _cached_source kubectl /Users/azuan.zairein/.rd/bin/kubectl kubectl completion zsh

  # bun completions
  [ -s "/Users/azuan.zairein/.bun/_bun" ] && source "/Users/azuan.zairein/.bun/_bun"

  # mise initial hook (sets up tool paths for current dir)
  _mise_hook

  precmd_functions=(${precmd_functions:#_zsh_deferred_init})
  unfunction _zsh_deferred_init
}
precmd_functions=(_zsh_deferred_init ${precmd_functions[@]})
