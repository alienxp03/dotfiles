# Uncomment to measure startup time (uses $SECONDS from process spawn)
# typeset -F SECONDS

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -o interactive ]] && command -v direnv >/dev/null 2>&1; then
  eval "$(direnv export zsh)"
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZVM_INIT_MODE=sourcing

# --- Immediate: source plugins inline (skip antidote runtime) ---
# Antidote uses different cache roots on macOS and Linux. Keep the encoded
# directory names so existing macOS caches remain usable, but bootstrap missing
# plugins on fresh Linux hosts such as hades.
if [[ "$(uname -s)" == "Darwin" ]]; then
  _antidote_cache_root="${XDG_CACHE_HOME:-$HOME/Library/Caches}/antidote"
else
  _antidote_cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
fi
_ap="$_antidote_cache_root/https-COLON--SLASH--SLASH-github.com-SLASH-"

_zsh_plugin_dir() {
  local repo="$1" encoded dir
  encoded="${repo//\//-SLASH-}"
  dir="${_ap}${encoded}"
  if [[ ! -d "$dir" && -n "${commands[git]:-}" ]]; then
    mkdir -p "$_antidote_cache_root"
    git clone --depth 1 --quiet "https://github.com/$repo.git" "$dir" 2>/dev/null || true
  fi
  [[ -d "$dir" ]] && print -r -- "$dir"
}

_zsh_source_if_readable() {
  [[ -r "$1" ]] && source "$1"
}

# powerlevel10k (needed for prompt)
_p10k_dir="$(_zsh_plugin_dir romkatv/powerlevel10k)"
if [[ -n "$_p10k_dir" ]]; then
  fpath+=( "$_p10k_dir" )
  _zsh_source_if_readable "$_p10k_dir/powerlevel10k.zsh-theme"
  _zsh_source_if_readable "$_p10k_dir/powerlevel9k.zsh-theme"
fi

# zsh-completions (just fpath, near-zero cost)
_zsh_completions_dir="$(_zsh_plugin_dir zsh-users/zsh-completions)"
if [[ -n "$_zsh_completions_dir" ]]; then
  fpath+=( "$_zsh_completions_dir" )
  _zsh_source_if_readable "$_zsh_completions_dir/zsh-completions.plugin.zsh"
fi

# zsh-autosuggestions (needed immediately for typing)
_zsh_autosuggestions_dir="$(_zsh_plugin_dir zsh-users/zsh-autosuggestions)"
if [[ -n "$_zsh_autosuggestions_dir" ]]; then
  fpath+=( "$_zsh_autosuggestions_dir" )
  _zsh_source_if_readable "$_zsh_autosuggestions_dir/zsh-autosuggestions.plugin.zsh"
fi

_zsh_completion_dir="$HOME/.zsh/completions"
fpath=( "$_zsh_completion_dir" $fpath )

# Load completions; use the fast cache only when it is fresh and custom
# completions have not changed since the dump was written.
autoload -Uz compinit
zmodload zsh/datetime 2>/dev/null
zmodload zsh/stat 2>/dev/null
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
_zcompdump_mtime=0
_zcompdump_stale=0
if [[ -f "$_zcompdump" ]]; then
  _zcompdump_mtime="$(zstat +mtime "$_zcompdump" 2>/dev/null)"
  _zcompdump_mtime="${_zcompdump_mtime:-0}"
  if [[ -d "$_zsh_completion_dir" ]]; then
    for _zsh_completion in "$_zsh_completion_dir"/_*(N); do
      if [[ -e "$_zsh_completion" && "$_zsh_completion" -nt "$_zcompdump" ]]; then
        _zcompdump_stale=1
        break
      fi
    done
  fi
else
  _zcompdump_stale=1
fi
if (( ! _zcompdump_stale && _zcompdump_mtime > EPOCHSECONDS - 86400 )); then
  compinit -C
else
  compinit
fi
unset _zsh_completion_dir _zcompdump _zcompdump_mtime _zcompdump_stale _zsh_completion

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Cache eval output — regenerates when binary changes
_cached_source() {
  local cache=~/.cache/zsh/$1.zsh bin=$2
  shift 2
  mkdir -p "${cache:h}"
  if [[ -x $bin && ( ! -f $cache || $bin -nt $cache ) ]]; then
    "$@" > $cache 2>/dev/null
    zcompile $cache 2>/dev/null
  fi
  [[ -r $cache ]] && source $cache
}

# mise — load definitions only, defer the hook-env subprocess
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
export MISE_ACTIVATE_AGGRESSIVE=1
_mise_bin="${commands[mise]:-$HOME/.local/bin/mise}"
if [[ -x "$_mise_bin" ]]; then
  mkdir -p ~/.cache/zsh
  if [[ ! -f ~/.cache/zsh/mise_fast.zsh || "$_mise_bin" -nt ~/.cache/zsh/mise_fast.zsh ]]; then
    "$_mise_bin" activate zsh | sed '/_mise_hook$/d' > ~/.cache/zsh/mise_fast.zsh
    zcompile ~/.cache/zsh/mise_fast.zsh 2>/dev/null
  fi
  source ~/.cache/zsh/mise_fast.zsh
fi

source "$HOME/.config/zsh/init.zsh"
if [[ -n "${JAVA_HOME:-}" && ! -d "$JAVA_HOME" ]]; then
  unset JAVA_HOME
fi
# Apply mise tool env in non-interactive shells too, so repo-local versions
# work for commands like `zsh -lc` and editor-integrated tasks.
if [[ ! -o interactive ]]; then
  _mise_hook
fi
if (( $+commands[zoxide] )); then
  _cached_source zoxide "$commands[zoxide]" zoxide init zsh
fi
if (( $+commands[fzf] )) && [[ -t 0 && -t 1 ]]; then
  _cached_source fzf "$commands[fzf]" fzf --zsh
fi

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
[[ -d "$HOME/.rd/bin" ]] && export PATH="$HOME/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# --- Deferred: loaded after first prompt renders ---
_zsh_deferred_init() {
  # Heavy plugins
  local _fzf_tab_dir="$(_zsh_plugin_dir Aloxaf/fzf-tab)"
  if [[ -n "$_fzf_tab_dir" ]]; then
    fpath+=( "$_fzf_tab_dir" )
    _zsh_source_if_readable "$_fzf_tab_dir/fzf-tab.plugin.zsh"
  fi
  local _zvm_dir="$(_zsh_plugin_dir jeffreytse/zsh-vi-mode)"
  if [[ -n "$_zvm_dir" ]]; then
    fpath+=( "$_zvm_dir" )
    _zsh_source_if_readable "$_zvm_dir/zsh-vi-mode.plugin.zsh"
  fi
  local _zsh_highlight_dir="$(_zsh_plugin_dir zsh-users/zsh-syntax-highlighting)"
  if [[ -n "$_zsh_highlight_dir" ]]; then
    fpath+=( "$_zsh_highlight_dir" )
    _zsh_source_if_readable "$_zsh_highlight_dir/zsh-syntax-highlighting.plugin.zsh"
  fi

  # atuin shell history
  (( $+commands[atuin] )) && _cached_source atuin "$commands[atuin]" atuin init zsh

  # kubectl completions
  (( $+commands[kubectl] )) && _cached_source kubectl "$commands[kubectl]" kubectl completion zsh

  # bun completions
  [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

  # mise initial hook (sets up tool paths for current dir)
  (( $+functions[_mise_hook] )) && _mise_hook

  (( $+commands[wktree] )) && eval "$(wktree init zsh)"
  (( $+commands[workmux] )) && eval "$(workmux completions zsh)"

  precmd_functions=(${precmd_functions:#_zsh_deferred_init})
  unfunction _zsh_deferred_init
}
# _zshrc_startup_timer() {
#   printf >&2 '\nShell ready in %.0fms\n' $(( SECONDS * 1000 ))
#   precmd_functions=(${precmd_functions:#_zshrc_startup_timer})
#   unfunction _zshrc_startup_timer
# }
# precmd_functions=(_zshrc_startup_timer _zsh_deferred_init ${precmd_functions[@]})
if command -v direnv >/dev/null 2>&1; then
  unfunction _direnv_hook 2>/dev/null || true
  eval "$(direnv hook zsh)"
fi

precmd_functions=(_zsh_deferred_init ${precmd_functions[@]})
export PATH="$PATH:$HOME/.local/bin"

# Added by LM Studio CLI (lms)
[[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section
unset _p10k_dir _zsh_completions_dir _zsh_autosuggestions_dir _mise_bin

