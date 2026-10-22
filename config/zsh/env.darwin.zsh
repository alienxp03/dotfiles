# Kitty skips system rc files. Load their PATH and UTF-8 settings with builtins
# instead of starting path_helper and locale for each split.
if [[ ! -o globalrcs ]]; then
	export LANG="${LANG:-C.UTF-8}"
	setopt combiningchars
	disable log
	typeset -a _zsh_system_paths
	for _zsh_path_file in /etc/paths /etc/paths.d/*(N); do
		[[ ! -r $_zsh_path_file ]] || _zsh_system_paths+=("${(@f)$(<"$_zsh_path_file")}")
	done
	path=("${_zsh_system_paths[@]}" "${path[@]}")
	unset _zsh_system_paths _zsh_path_file
fi

# Hardcoded brew shellenv (avoids ~55ms subprocess)
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
fpath[1,0]="/opt/homebrew/share/zsh/site-functions"
export PATH="/Applications/kitty.app/Contents/MacOS:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
[ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
export XDG_CONFIG_HOME="$HOME/.config"

alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
