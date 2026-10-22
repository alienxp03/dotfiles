source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/aliases.private.zsh" ]] && source "$HOME/.config/zsh/aliases.private.zsh"
[[ -f "$HOME/.config/zsh/aliases.local.zsh" ]] && source "$HOME/.config/zsh/aliases.local.zsh"
[[ -f "$HOME/.config/zsh/functions.local.zsh" ]] && source "$HOME/.config/zsh/functions.local.zsh"
source "$HOME/.config/zsh/functions.zsh"

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

# Auto-cd: typing a bare directory name changes into it
# (e.g. `.config` == `cd .config`).
setopt autocd

# Completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z} r:|[._-]=* l:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Keep Kitty shell integration active after reloading with `exec zsh`.
if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
	export KITTY_SHELL_INTEGRATION="no-title"
	autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
	kitty-integration
	unfunction kitty-integration

	# Name each Kitty tab once, using the directory of its first shell.
	# The exported marker is inherited by windows launched from this tab.
	if [[ -z ${KITTY_TAB_TITLE_INITIALIZED:-} ]]; then
		(kitty @ set-tab-title "${PWD:t}" >/dev/null 2>&1 &|)
		export KITTY_TAB_TITLE_INITIALIZED=1
	fi
fi

# Set Herdr pane labels in the background, so its API cannot delay input.
if [[ -n ${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}} ]]; then
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
	(_herdr_auto_name_pane >/dev/null 2>&1 &|)
fi
