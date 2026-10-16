# Two-phase startup: phase 1 leaves a prompt that accepts input in ~100ms;
# phase 2 (completions, plugins, hooks, powerlevel10k) loads while zle sits
# idle. A command typed before phase 2 lands runs it synchronously first, so
# aliases, env, and hooks are always in place before anything executes.

typeset -F SECONDS
typeset -g _ZSH_PHASE2_DONE=0

if [[ ! -o interactive ]]; then
	# Non-interactive sourcing (editor tasks, wrappers): mise env only.
	export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
	[[ -r ~/.cache/zsh/mise_fast.zsh ]] && source ~/.cache/zsh/mise_fast.zsh
	(($+functions[_mise_hook])) && _mise_hook
	return
fi

# --- Phase 1: minimal interactive shell ---

# Static PATH exports (no subprocesses) so early commands resolve correctly.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
[[ -d "$HOME/.rd/bin" ]] && export PATH="$HOME/.rd/bin:$PATH"
[[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
export PATH="$PATH:$HOME/.local/bin"

# zsh-autosuggestions: the only plugin needed while typing, sourced straight
# from the antidote cache (the plugin-dir helpers arrive with phase 2).
_zsh_as_dir="$HOME/Library/Caches/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-zsh-autosuggestions"
if [[ -r "$_zsh_as_dir/zsh-autosuggestions.plugin.zsh" ]]; then
	fpath+=("$_zsh_as_dir")
	source "$_zsh_as_dir/zsh-autosuggestions.plugin.zsh"
fi
unset _zsh_as_dir

# Kitty shell integration must wrap the first prompt; the tab-title subprocess
# is deferred to phase 2.
if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
	export KITTY_SHELL_INTEGRATION="no-title"
	autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
	kitty-integration
	unfunction kitty-integration
fi

# Placeholder prompt; powerlevel10k replaces it once phase 2 lands.
PS1='%F{blue}%~%f %F{magenta}❯%f '
RPROMPT=''

# --- Phase 2 ---
_zsh_phase2() {
	((_ZSH_PHASE2_DONE)) && return 0
	_ZSH_PHASE2_DONE=1
	preexec_functions=(${preexec_functions:#_zsh_phase2_preexec})
	[[ ${_ZSH_STARTUP_TRACE:-} ]] && printf '\n[phase2-start %.0fms]\n' $((SECONDS * 1000))

	# Load the initial directory environment before anything else touches it.
	if command -v direnv >/dev/null 2>&1; then
		eval "$(direnv export zsh 2>/dev/null)"
	fi

	# Antidote uses different cache roots on macOS and Linux. Keep the encoded
	# directory names so existing macOS caches remain usable, but bootstrap
	# missing plugins on fresh Linux hosts such as hades.
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
		fpath+=("$_p10k_dir")
		_zsh_source_if_readable "$_p10k_dir/powerlevel10k.zsh-theme"
		_zsh_source_if_readable "$_p10k_dir/powerlevel9k.zsh-theme"
	fi

	# zsh-completions (just fpath, near-zero cost)
	_zsh_completions_dir="$(_zsh_plugin_dir zsh-users/zsh-completions)"
	if [[ -n "$_zsh_completions_dir" ]]; then
		fpath+=("$_zsh_completions_dir")
		_zsh_source_if_readable "$_zsh_completions_dir/zsh-completions.plugin.zsh"
	fi

	_zsh_completion_dir="$HOME/.zsh/completions"
	fpath=("$_zsh_completion_dir" $fpath)

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
	if ((! _zcompdump_stale && _zcompdump_mtime > EPOCHSECONDS - 86400)); then
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
		if [[ -x $bin && (! -f $cache || $bin -nt $cache) ]]; then
			"$@" >$cache 2>/dev/null
			zcompile $cache 2>/dev/null
		fi
		[[ -r $cache ]] && source $cache
	}

	# mise — load definitions only, defer the hook-env subprocess
	export MISE_ACTIVATE_AGGRESSIVE=1
	_mise_bin="${commands[mise]:-$HOME/.local/bin/mise}"
	if [[ -x "$_mise_bin" ]]; then
		mkdir -p ~/.cache/zsh
		if [[ ! -f ~/.cache/zsh/mise_fast.zsh || "$_mise_bin" -nt ~/.cache/zsh/mise_fast.zsh ]]; then
			"$_mise_bin" activate zsh | sed '/_mise_hook$/d' >~/.cache/zsh/mise_fast.zsh
			zcompile ~/.cache/zsh/mise_fast.zsh 2>/dev/null
		fi
		source ~/.cache/zsh/mise_fast.zsh
	fi

	source "$HOME/.config/zsh/init.zsh"

	# Cache Just's dynamic completion function and share it with the `js` alias.
	if (($+commands[just])); then
		_cached_source just "$commands[just]" env JUST_COMPLETE=zsh "$commands[just]"
		compdef _clap_dynamic_completer_just just js
	fi

	if [[ -n "${JAVA_HOME:-}" && ! -d "$JAVA_HOME" ]]; then
		unset JAVA_HOME
	fi
	if (($+commands[zoxide])); then
		_cached_source zoxide "$commands[zoxide]" zoxide init zsh
	fi
	if (($+commands[fzf])) && [[ -t 0 && -t 1 ]]; then
		_cached_source fzf "$commands[fzf]" fzf --zsh
	fi

	# Give unnamed Herdr panes stable workspace-number labels for sidebar rows.
	_herdr_auto_name_pane() {
		local pane_id="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
		[[ -n "$pane_id" ]] || return
		[[ -n "${_HERDR_PANE_NAMED:-}" ]] && return
		(($+commands[herdr] && $+commands[jq])) || return

		local snapshot details label workspace_id workspace_label pane_number
		snapshot="$(herdr api snapshot 2>/dev/null)" || return
		label="$(jq -r --arg pane_id "$pane_id" '
			.result.snapshot.panes[] | select(.pane_id == $pane_id) | .label // empty
		' <<<"$snapshot")" || return
		[[ -z "$label" ]] || return
		details="$(jq -r --arg pane_id "$pane_id" '
			.result.snapshot as $snapshot
			| ($snapshot.panes[] | select(.pane_id == $pane_id)) as $pane
			| (($snapshot.workspaces | map(select(.workspace_id == $pane.workspace_id))[0].label) // "") as $workspace_label
			| ([$snapshot.panes[] | select(.workspace_id == $pane.workspace_id) | .pane_id] | sort | index($pane_id) + 1) as $pane_number
			| [$pane.workspace_id, $workspace_label, $pane_number]
			| @tsv
		' <<<"$snapshot")" || return
		IFS=$'\t' read -r workspace_id workspace_label pane_number <<<"$details"
		[[ -n "$workspace_id" ]] || return
		[[ -n "$workspace_label" ]] || workspace_label="${PWD:t}"
		[[ "$pane_number" == <-> ]] || return

		herdr pane rename "$pane_id" "${workspace_label}-${pane_number}" >/dev/null 2>&1 || return
		_HERDR_PANE_NAMED=1
	}

	# Heavy plugins, previously deferred to first prompt via precmd.
	local _fzf_tab_dir="$(_zsh_plugin_dir Aloxaf/fzf-tab)"
	if [[ -n "$_fzf_tab_dir" ]]; then
		fpath+=("$_fzf_tab_dir")
		_zsh_source_if_readable "$_fzf_tab_dir/fzf-tab.plugin.zsh"
	fi
	local _zvm_dir="$(_zsh_plugin_dir jeffreytse/zsh-vi-mode)"
	if [[ -n "$_zvm_dir" ]]; then
		fpath+=("$_zvm_dir")
		_zsh_source_if_readable "$_zvm_dir/zsh-vi-mode.plugin.zsh"
	fi
	local _zsh_highlight_dir="$(_zsh_plugin_dir zsh-users/zsh-syntax-highlighting)"
	if [[ -n "$_zsh_highlight_dir" ]]; then
		fpath+=("$_zsh_highlight_dir")
		_zsh_source_if_readable "$_zsh_highlight_dir/zsh-syntax-highlighting.plugin.zsh"
	fi

	# atuin shell history
	(($+commands[atuin])) && _cached_source atuin "$commands[atuin]" atuin init zsh

	# kubectl completions
	(($+commands[kubectl])) && _cached_source kubectl "$commands[kubectl]" kubectl completion zsh

	# bun completions
	[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

	if command -v direnv >/dev/null 2>&1; then
		unfunction _direnv_hook 2>/dev/null || true
		eval "$(direnv hook zsh)"
	fi

	# Update mise before direnv on the first and subsequent prompts.
	if (($+functions[_mise_hook_precmd])); then
		precmd_functions=(${precmd_functions:#_mise_hook_precmd})
		precmd_functions=(_mise_hook_precmd ${precmd_functions[@]})
	fi

	precmd_functions=(_herdr_auto_name_pane ${precmd_functions[@]})

	# Name each Kitty tab once, using the directory of its first shell. The
	# exported marker is inherited by windows launched from this tab.
	if [[ -n "$KITTY_INSTALLATION_DIR" && -z ${KITTY_TAB_TITLE_INITIALIZED:-} ]]; then
		kitty @ set-tab-title "${PWD:t}" >/dev/null 2>&1
		export KITTY_TAB_TITLE_INITIALIZED=1
	fi

	# Worktrunk: let `wt switch`, `wt merge`, and `wt remove` change this shell's
	# directory. `command wt` bypasses the wrapper while loading its definition.
	if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

	unset _p10k_dir _zsh_completions_dir _zsh_autosuggestions_dir _mise_bin

	# Swap the placeholder for the real prompt without waiting for the next
	# command: run the freshly registered precmd hooks, then force a repaint.
	if [[ -z "${ZSH_EXECUTION_STRING:-}" ]]; then
		local _phase2_hook
		for _phase2_hook in $precmd_functions; do
			$_phase2_hook
		done
		zle -I
	fi
	[[ ${_ZSH_STARTUP_TRACE:-} ]] && printf '\n[phase2-done %.0fms]\n' $((SECONDS * 1000))
}

# A command executed before phase 2 lands gets it synchronously first.
_zsh_phase2_preexec() {
	preexec_functions=(${precmd_functions:#_zsh_phase2_preexec})
	_zsh_phase2
}
preexec_functions+=(_zsh_phase2_preexec)

if [[ -n "${ZSH_EXECUTION_STRING:-}" ]]; then
	_zsh_phase2 # `zsh -i -c` never enters the idle zle loop sched needs
else
	sched +0:00 _zsh_phase2
fi
