# Use Mise shims for tools and keep shell startup work small.
typeset -U path fpath
path=("${(@)path:#${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs/*}")
source "$HOME/.config/zsh/env.zsh"
case $OSTYPE in
darwin*) source "$HOME/.config/zsh/env.darwin.zsh" ;;
linux*) source "$HOME/.config/zsh/env.linux.zsh" ;;
esac
path=("${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims" "$HOME/.local/bin" "${(@)path:#${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs/*}")
fpath=("$HOME/.zsh/completions" $fpath)

# Load completions on the first Tab. An absent or old dump cannot delay
# a new shell.
typeset -ga _zsh_compdefs=()
compdef() { _zsh_compdefs+=("${(j: :)${(q)@}}") }
_zsh_complete() {
	unfunction compdef
	autoload -Uz compinit
	compinit
	local definition
	for definition in "${_zsh_compdefs[@]}"; do
		eval "compdef $definition"
	done
	unset _zsh_compdefs

	bindkey -M viins '^I' expand-or-complete
	bindkey -M emacs '^I' expand-or-complete
	local plugin_root
	if [[ $OSTYPE == darwin* ]]; then
		plugin_root="${XDG_CACHE_HOME:-$HOME/Library/Caches}/antidote"
	else
		plugin_root="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
	fi
	local fzf_tab="$plugin_root/https-COLON--SLASH--SLASH-github.com-SLASH-Aloxaf-SLASH-fzf-tab/fzf-tab.plugin.zsh"
	[[ ! -r $fzf_tab ]] || source "$fzf_tab"
	[[ ! -s $HOME/.bun/_bun ]] || source "$HOME/.bun/_bun"
	if (( $+widgets[fzf-tab-complete] )); then
		zle fzf-tab-complete
	else
		zle expand-or-complete
	fi
}
zle -N _zsh_complete

# Source definitions only. Generate integrations when first used, never on
# startup. Existing caches contain shell functions and completion definitions.
_cached_source() {
	local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/$1.zsh" bin=$2
	shift 2
	if [[ ! -s $cache || $bin -nt $cache ]]; then
		mkdir -p "${cache:h}"
		"$@" >"$cache" || return
	fi
	source "$cache"
}

source "$HOME/.config/zsh/init.zsh"

# A native prompt with the Git branch read from HEAD.
PROMPT=$'%F{blue}%~%f\n%(?.%F{green}.%F{red})❯%f '
RPROMPT=''

# Native vi mode avoids a plugin callback on every input character.
bindkey -v
KEYTIMEOUT=1
bindkey -M viins '^[f' forward-word
bindkey -M viins '^[b' backward-word
bindkey -M viins '^I' _zsh_complete
bindkey -M emacs '^I' _zsh_complete

# Use Mise's global Atuin executable directly. Its stable symlink follows
# upgrades and avoids running the Mise shim for each history operation.
for _atuin_bin in "${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs/atuin/global"/{,*/}atuin(N-*); do
	hash atuin="$_atuin_bin"
	break
done
unset _atuin_bin

# Load Atuin's own integration on the first command or history action. Its
# session UUID and search index do not need to delay the first prompt.
if (( $+commands[atuin] )); then
	export ATUIN_TMUX_POPUP=false
	setopt interactivecomments
	_atuin_init() {
		local cache_id=${commands[atuin]:A}
		cache_id=${cache_id//\//_}
		_cached_source "atuin-$cache_id" "$commands[atuin]" atuin init zsh || return
		# Older Atuin versions can omit optional widgets such as AI search.
		if [[ $widgets[self-atuin-ai-question-mark] == user:_atuin_widget_init ]]; then
			zle -A self-insert self-atuin-ai-question-mark
		fi
		unfunction _atuin_init
	}
	# These proxies keep the official hook names. Atuin replaces each function
	# in place, so the first command is recorded once without duplicate hooks.
	_atuin_preexec() {
		_atuin_init || return
		_atuin_preexec "$@"
	}
	_atuin_zshaddhistory() {
		[[ $1 == \#* && ${1%$'\n'} != *$'\n'* ]] || return 0
		_atuin_init || return
		_atuin_zshaddhistory "$@"
	}
	_atuin_widget_init() {
		local widget=$WIDGET
		_atuin_init || return
		zle "$widget"
	}
	autoload -Uz add-zsh-hook
	add-zsh-hook preexec _atuin_preexec
	add-zsh-hook zshaddhistory _atuin_zshaddhistory
	for _atuin_widget in atuin-search atuin-search-viins atuin-search-vicmd atuin-up-search atuin-up-search-viins atuin-up-search-vicmd self-atuin-ai-question-mark; do
		zle -N "$_atuin_widget" _atuin_widget_init
	done
	unset _atuin_widget
	bindkey -M emacs '^R' atuin-search
	bindkey -M viins '^R' atuin-search-viins
	bindkey -M vicmd '/' atuin-search
	bindkey -M emacs '^[[A' atuin-up-search
	bindkey -M viins '^[[A' atuin-up-search-viins
	bindkey -M vicmd '^[[A' atuin-up-search-vicmd
	bindkey -M emacs '^[OA' atuin-up-search
	bindkey -M viins '^[OA' atuin-up-search-viins
	bindkey -M vicmd '^[OA' atuin-up-search-vicmd
	bindkey -M vicmd 'k' atuin-up-search-vicmd
	bindkey -M viins '?' self-atuin-ai-question-mark
	bindkey -M emacs '?' self-atuin-ai-question-mark
fi

# Load Worktrunk on its first command, including its directory-change wrapper.
if (( $+commands[wt] )); then
	wt() {
		unfunction wt
		eval "$(command wt config shell init zsh)"
		wt "$@"
	}
fi

_zsh_just_complete() {
	_cached_source just "$commands[just]" env JUST_COMPLETE=zsh "$commands[just]" || return
	_clap_dynamic_completer_just "$@"
}
(( ! $+commands[just] )) || compdef _zsh_just_complete just js

# Zoxide records directory changes, with no process at the first prompt.
if (( $+commands[zoxide] )); then
	if [[ -r ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zoxide.zsh ]]; then
		source "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zoxide.zsh"
	else
		z() {
			unfunction z
			_cached_source zoxide "$commands[zoxide]" zoxide init zsh --hook pwd
			z "$@"
		}
		zi() {
			unfunction zi
			_cached_source zoxide "$commands[zoxide]" zoxide init zsh --hook pwd
			zi "$@"
		}
	fi
fi

# Load Fzf only when its file or directory picker is requested.
_zsh_fzf() {
	local widget=$1 vi_tab emacs_tab vi_history emacs_history
	vi_tab=$(bindkey -M viins '^I')
	emacs_tab=$(bindkey -M emacs '^I')
	vi_history=$(bindkey -M viins '^R')
	emacs_history=$(bindkey -M emacs '^R')
	_cached_source fzf "$commands[fzf]" fzf --zsh || return
	eval "bindkey -M viins $vi_tab"
	eval "bindkey -M emacs $emacs_tab"
	eval "bindkey -M viins $vi_history"
	eval "bindkey -M emacs $emacs_history"
	zle "$widget"
}
_zsh_fzf_file() { _zsh_fzf fzf-file-widget }
_zsh_fzf_cd() { _zsh_fzf fzf-cd-widget }
if (( $+commands[fzf] )); then
	zle -N _zsh_fzf_file
	zle -N _zsh_fzf_cd
	bindkey -M viins '^T' _zsh_fzf_file
	bindkey -M emacs '^T' _zsh_fzf_file
	bindkey -M viins '^[c' _zsh_fzf_cd
	bindkey -M emacs '^[c' _zsh_fzf_cd
fi

_zsh_kubectl_complete() {
	_cached_source kubectl "$commands[kubectl]" kubectl completion zsh || return
	compdef _kubectl kubectl k
	_kubectl "$@"
}
(( ! $+commands[kubectl] )) || compdef _zsh_kubectl_complete kubectl k

# Run direnv only in a directory tree with .envrc, or when unloading an old
# environment. Plain directories require only file checks.
_direnv_hook() {
	local dir=$PWD
	if [[ -z ${DIRENV_DIR:-} ]]; then
		while [[ ! -f $dir/.envrc ]]; do
			[[ $dir != / ]] || return 0
			dir=${dir:h}
		done
	fi
	eval "$(command direnv export zsh)"
}
if (( $+commands[direnv] )); then
	precmd_functions=(${precmd_functions:#_direnv_hook} _direnv_hook)
	chpwd_functions=(${chpwd_functions:#_direnv_hook} _direnv_hook)
fi

# Add installed completion definitions without loading input plugins.
if [[ $OSTYPE == darwin* ]]; then
	_zsh_plugin_root="${XDG_CACHE_HOME:-$HOME/Library/Caches}/antidote"
else
	_zsh_plugin_root="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
fi
_zsh_plugin_root+=/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-
[[ ! -r ${_zsh_plugin_root}zsh-completions/src ]] || fpath+=("${_zsh_plugin_root}zsh-completions/src")
unset _zsh_plugin_root

source "$HOME/.config/zsh/git-prompt.zsh"
