# Run global just recipes. Keep the public command name dotted for convenience.
jg() {
	if [[ "$1" == "llama-qwen3.8-27b" ]]; then
		shift
		just --global-justfile llama-qwen3-8-27b "$@"
	else
		just --global-justfile "$@"
	fi
}

_jg() {
	local -a recipes
	recipes=(
		'llama-qwen3.8-27b:Serve Qwen 3.8 27B with llama'
	)
	_describe 'global just recipe' recipes
}
compdef _jg jg

# Setup a 3-pane workspace in a new window
function ide_tmux() {
	local dir_name="${PWD##*/}"
	local remote_url repo_name

	if [[ -e .git ]]; then
		remote_url=$(git remote get-url origin 2>/dev/null)
		if [[ -n "$remote_url" ]]; then
			repo_name=$(basename -s .git "$remote_url")
			[[ -n "$repo_name" ]] && dir_name="$repo_name"
		fi
	fi

	tmux rename-window "${dir_name}-code"
	tmux split-window -h -c "$PWD"
	tmux split-window -v -c "$PWD"
	tmux send-keys -t 1 "nvim" C-m
	tmux send-keys -t 3 "pix" C-m
	tmux select-pane -t 1
}

# Setup a 3-pane workspace in Kitty
function ide_kitty() {
	local dir_name="${PWD##*/}"
	local editor_window="$KITTY_WINDOW_ID"
	local shell_window

	# The tab title is initialized by the first shell in the tab.
	# Do not re-enter the splits layout here: Kitty rebuilds its split tree,
	# flattening the right-hand nested split into three columns.

	# Launch a persistent shell directly. The clone helper's window can vanish
	# when its short-lived cloning process exits.
	shell_window=$(kitty @ launch \
		--self \
		--source-window "id:$editor_window" \
		--copy-env \
		--next-to "id:$editor_window" \
		--cwd="$PWD" \
		--location=vsplit \
		"${SHELL:-/bin/zsh}" -l) || return 1

	kitty @ launch \
		--self \
		--next-to "id:$shell_window" \
		--cwd="$PWD" \
		--location=hsplit \
		pi --approve >/dev/null || return 1

	kitty @ focus-window --match "id:$editor_window" || return 1
	nvim
}

function ide() {
	if [[ -n "$KITTY_WINDOW_ID" ]]; then
		ide_kitty
	else
		ide_tmux
	fi
}

# Docker exec into running container with fzf
dex() {
	local container
	container=$(docker ps --format '{{.Names}}' | fzf)
	[ -n "$container" ] && docker exec -it "$container" "${1:-bash}"
}

# Git worktree with fzf
gwt() {
	local worktree
	worktree=$(git worktree list | fzf | awk '{print $1}')
	[ -n "$worktree" ] && cd "$worktree"
}

__git_worktree_sanitize_branch() {
	echo "$1" | sed -E 's#[/[:space:]]+#-#g; s#[^[:alnum:]_.-]+#-#g; s#^-+##; s#-+$##'
}

__git_worktree_fetch() {
	local repo_root="$1"
	local label="$2"

	git -C "$repo_root" fetch || echo "${label}: fetch failed, continuing with local refs"
}

__git_worktree_copy_local_files() {
	local source_dir="$1"
	local target_dir="$2"
	local item

	(
		cd "$source_dir" || exit 1
		for item in .env(N) .env.*(N) .mcp.json(N) .claude(N) .aider*(N) AGENTS.override.md(N) docs.local(N); do
			[[ -e "$target_dir/$item" ]] && continue
			cp -R "$item" "$target_dir/$item"
			echo "Copied $item"
		done
	)
}

__git_worktree_create_branch() {
	local repo_root="$1"
	local worktree_path="$2"
	local branch="$3"
	local default_ref="$4"

	if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
		git -C "$repo_root" worktree add "$worktree_path" "$branch" || return 1
	elif git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		git -C "$repo_root" worktree add "$worktree_path" -b "$branch" "origin/$branch" || return 1
	elif [[ -n "$default_ref" ]]; then
		git -C "$repo_root" rev-parse --verify --quiet "${default_ref}^{commit}" >/dev/null || return 1
		git -C "$repo_root" worktree add --no-track "$worktree_path" -b "$branch" "$default_ref" || return 1
	else
		git -C "$repo_root" worktree add "$worktree_path" -b "$branch" || return 1
	fi
}

__git_worktree_branch_path() {
	local repo_root="$1"
	local branch="$2"

	git -C "$repo_root" worktree list --porcelain | awk -v branch="refs/heads/$branch" '
    /^worktree / { path = substr($0, 10) }
    /^branch / {
      ref = substr($0, 8)
      if (ref == branch) {
        print path
        exit
      }
    }
  '
}

__tmux_prepare_ide_panes() {
	local editor_pane="$1"
	local worktree_path="$2"
	local install_cmd="$3"
	local install_pane agent_pane

	install_pane=$(tmux split-window -h -t "$editor_pane" -c "$worktree_path" -P -F "#{pane_id}") || return 1
	agent_pane=$(tmux split-window -v -t "$install_pane" -c "$worktree_path" -P -F "#{pane_id}") || return 1

	tmux send-keys -t "$editor_pane" "nvim" C-m
	tmux send-keys -t "$install_pane" "$install_cmd" C-m
	tmux send-keys -t "$agent_pane" "cox" C-m
	tmux select-pane -t "$editor_pane"
}

__tmux_new_ide_window() {
	local session_name="$1"
	local window_name="$2"
	local worktree_path="$3"
	local install_cmd="$4"
	local editor_pane

	editor_pane=$(tmux new-window -t "$session_name:" -n "$window_name" -c "$worktree_path" -P -F "#{pane_id}") || return 1
	__tmux_prepare_ide_panes "$editor_pane" "$worktree_path" "$install_cmd"
}

# Git worktree enter
gwn() {
	local repo_root main_checkout repo_name branch sanitized worktree_root worktree_path

	repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
		echo "gn: not inside a git repository"
		return 1
	}

	main_checkout=$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	main_checkout="${main_checkout:h}"
	repo_name="${main_checkout:t}"

	read "branch?Branch name: "
	branch="${branch#origin/}"
	if [[ -z "$branch" ]]; then
		echo "gn: branch name is required"
		return 1
	fi

	sanitized=$(__git_worktree_sanitize_branch "$branch")
	worktree_root="${GIT_WORKTREE_ROOT:-$HOME/workspace/worktrees}"
	worktree_path="${worktree_root}/${repo_name}__${sanitized}"

	if [[ ! -d "$worktree_path" ]]; then
		mkdir -p "$worktree_root" || return 1
		__git_worktree_fetch "$repo_root" "gn"
		__git_worktree_create_branch "$repo_root" "$worktree_path" "$branch" "" || return 1
		__git_worktree_copy_local_files "$main_checkout" "$worktree_path"
	fi

	cd "$worktree_path"
}

# Mark Herdr windows so Kitty passes Ctrl+H/J/K/L through.
function herdr() {
	local exit_status
	local mark_kitty_window=false

	if [[ -n ${KITTY_WINDOW_ID:-} ]] && command -v kitty >/dev/null 2>&1; then
		kitty @ set-user-vars herdr=1 >/dev/null 2>&1
		mark_kitty_window=true
	fi

	command herdr "$@"
	exit_status=$?

	if [[ $mark_kitty_window == true ]]; then
		kitty @ set-user-vars herdr >/dev/null 2>&1
	fi

	return $exit_status
}
