source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/aliases.private.zsh" ]] && source "$HOME/.config/zsh/aliases.private.zsh"
[[ -f "$HOME/.config/zsh/aliases.local.zsh" ]] && source "$HOME/.config/zsh/aliases.local.zsh"
[[ -f "$HOME/.config/zsh/functions.local.zsh" ]] && source "$HOME/.config/zsh/functions.local.zsh"
source "$HOME/.config/zsh/functions.zsh"
source "$HOME/.config/zsh/env.zsh"

# For cross-platform logics
if [ "$(uname -s)" = "Darwin" ]; then
	source "$HOME/.config/zsh/env.darwin.zsh"
elif [ "$(uname -s)" = "Linux" ]; then
	source "$HOME/.config/zsh/env.linux.zsh"
fi

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

# --- Keybindings ---
# Alt-F: accept one word of the autosuggestion (partial accept). Standard
# forward-word key; pairs with Alt-B (backward-word). Bound through zvm's
# after-init hook (runs at source time, after zvm's own keymap setup) so
# zsh-vi-mode doesn't clobber it. (Ctrl-L was kitty's window-nav key.)
function _zsh_bind_partial_accept() {
	(( $+functions[zvm_bindkey] )) && zvm_bindkey viins '^[f' forward-word
}
zvm_after_init_commands+=(_zsh_bind_partial_accept)

# Keep Kitty shell integration active after reloading with `exec zsh`.
if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
	export KITTY_SHELL_INTEGRATION="no-title"
	autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
	kitty-integration
	unfunction kitty-integration

	# Name each Kitty tab once, using the directory of its first shell.
	# The exported marker is inherited by windows launched from this tab.
	if [[ -z ${KITTY_TAB_TITLE_INITIALIZED:-} ]]; then
		kitty @ set-tab-title "${PWD:t}" >/dev/null 2>&1
		export KITTY_TAB_TITLE_INITIALIZED=1
	fi
fi
