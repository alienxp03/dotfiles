# Hardcoded brew shellenv (avoids ~55ms subprocess)
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
fpath[1,0]="/opt/homebrew/share/zsh/site-functions"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
[ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
export XDG_CONFIG_HOME="$HOME/.config"

alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
