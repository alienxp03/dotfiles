# Read HEAD with shell builtins. No Git process or file-status scan is needed.
(( ! $+functions[gitstatus_stop] )) || gitstatus_stop DOTFILES

_zsh_git_precmd() {
	local exit_status=$?
	if (( exit_status )); then
		_zsh_prompt_arrow='%F{red}❯%f '
	else
		_zsh_prompt_arrow='%F{green}❯%f '
	fi
	_zsh_git_prompt=''

	local dir=$PWD git_dir=${GIT_DIR:-} head branch
	if [[ -z $git_dir ]]; then
		while true; do
			if [[ -d $dir/.git ]]; then
				git_dir=$dir/.git
				break
			elif [[ -f $dir/.git ]]; then
				# Linked worktrees and submodules use a .git pointer file.
				IFS= read -r git_dir <"$dir/.git" || return 0
				[[ $git_dir == 'gitdir: '* ]] || return 0
				git_dir=${git_dir#gitdir: }
				[[ $git_dir == /* ]] || git_dir=$dir/$git_dir
				break
			fi
			[[ $dir != / ]] || return 0
			dir=${dir:h}
		done
	fi
	[[ -r $git_dir/HEAD ]] || return 0
	IFS= read -r head <"$git_dir/HEAD" || return 0
	if [[ $head == 'ref: refs/heads/'* ]]; then
		branch=${head#ref: refs/heads/}
	else
		branch=@${head[1,8]}
	fi
	_zsh_git_prompt=" %F{green}${branch//\%/%%}%f"
	return 0
}

typeset -g _zsh_git_prompt='' _zsh_prompt_arrow='%F{green}❯%f '
setopt promptsubst
PROMPT='%F{blue}%~%f${_zsh_git_prompt}'$'\n''${_zsh_prompt_arrow}'
precmd_functions=(_zsh_git_precmd ${precmd_functions:#_zsh_git_precmd})
