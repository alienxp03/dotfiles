function loop() {
	# while "$1"; do :; done
	for i in {0..10}; do
		echo $PWD
		$1
	done
}

function gotest() {
	DIR="$(PWD)"
	TEST_FILE=$1
	CODE_FILE="${TEST_FILE/_test.go/.go}"

	if [[ $TEST_FILE == *"_test.go"* ]]; then
		grc go test -cover -count=1 -v $CODE_FILE $TEST_FILE
	else
		grc go test -cover -race -count=1 -v $@
	fi
}

function gcb() {
	# Get the default branch (usually main or master)
	local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")

	local selected=$(
		{
			git for-each-ref --format='%(refname:short)	%(committerdate:relative)	%(authorname)	%(subject)' refs/heads |
				awk -v default="$default_branch" 'BEGIN{FS="\t"; OFS="\t"} {
          # Reconstruct the commit message from field 4 onwards
          commit_msg = $4
          for (i = 5; i <= NF; i++) {
            commit_msg = commit_msg " " $i
          }

          # Calculate padding needed for alignment (assuming max branch name + date + author is around 60 chars)
          branch_info = $1 " (" $2 ") [" $3 "]"
          padding = 70 - length(branch_info)
          if (padding < 1) padding = 1
          spaces = sprintf("%" padding "s", "")

          if ($1 == default) {
            printf "\033[34m%s\033[0m \033[92m(%s)\033[0m \033[36m[%s]\033[0m%s%s\n", $1, $2, $3, spaces, commit_msg
          } else {
            printf "\033[33m%s\033[0m \033[92m(%s)\033[0m \033[36m[%s]\033[0m%s%s\n", $1, $2, $3, spaces, commit_msg
          }
        }'

			git for-each-ref --format='%(refname:short)	%(committerdate:relative)	%(authorname)	%(subject)' refs/remotes |
				awk 'BEGIN{FS="\t"; OFS="\t"} {
          # Reconstruct the commit message from field 4 onwards
          commit_msg = $4
          for (i = 5; i <= NF; i++) {
            commit_msg = commit_msg " " $i
          }

          # Calculate padding needed for alignment (assuming max branch name + date + author is around 60 chars)
          branch_info = $1 " (" $2 ") [" $3 "]"
          padding = 70 - length(branch_info)
          if (padding < 1) padding = 1
          spaces = sprintf("%" padding "s", "")

          printf "\033[38;5;208m%s\033[0m \033[92m(%s)\033[0m \033[36m[%s]\033[0m%s%s\n", $1, $2, $3, spaces, commit_msg
        }'
		} |
			FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --multi=0 \
      --border-label '☘️  Git Branches ' --border=rounded \
      --header-lines 0 \
      --margin=1,2 \
      --padding=1 \
      --preview-window down,border-top,50% \
      --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
      --bind 'ctrl-o:execute-silent(branch_name=\$(echo {} | awk \"{print \\\$1}\" | sed \"s/\\x1b\\[[0-9;]*m//g\" | sed \"s|^origin/||\");
        remote_url=\$(git config --get remote.origin.url);
        if [[ \"\$remote_url\" =~ github.com ]]; then
          repo_path=\$(echo \"\$remote_url\" | sed -E \"s/.*github.com[:\\/](.+)(\\.git)?\$/\\1/\" | sed \"s/\\.git\$//\");
          open \"https://github.com/\$repo_path/tree/\$branch_name\" 2>/dev/null || xdg-open \"https://github.com/\$repo_path/tree/\$branch_name\" 2>/dev/null;
        elif [[ \"\$remote_url\" =~ gitlab ]]; then
          repo_path=\$(echo \"\$remote_url\" | sed -E \"s/.*gitlab[^\\/]*[:\\/](.+)(\\.git)?\$/\\1/\" | sed \"s/\\.git\$//\");
          open \"https://\$(echo \"\$remote_url\" | grep -oE \"gitlab[^\\/]*\")/\$repo_path/-/tree/\$branch_name\" 2>/dev/null || xdg-open \"https://\$(echo \"\$remote_url\" | grep -oE \"gitlab[^\\/]*\")/\$repo_path/-/tree/\$branch_name\" 2>/dev/null;
        elif [[ \"\$remote_url\" =~ bitbucket ]]; then
          repo_path=\$(echo \"\$remote_url\" | sed -E \"s/.*bitbucket.org[:\\/](.+)(\\.git)?\$/\\1/\" | sed \"s/\\.git\$//\");
          open \"https://bitbucket.org/\$repo_path/src/\$branch_name\" 2>/dev/null || xdg-open \"https://bitbucket.org/\$repo_path/src/\$branch_name\" 2>/dev/null;
        fi)' \
      --nth 1,1.. --delimiter '\t' \
      --no-hscroll --ansi \
      $FZF_DEFAULT_OPTS $FZF_CTRL_G_OPTS" \
				fzf-tmux -p90%,60% -- \
				--header '  CTRL-O: Open in browser │ CTRL-/: Toggle preview │ ENTER: Checkout  ' \
				--preview 'branch_name=$(echo {} | awk "{print \$1}" | sed "s/\x1b\[[0-9;]*m//g"); git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %C(cyan)[%an]%C(reset) %s" "$branch_name" -- 2>/dev/null | head -20 || echo "No commits found for branch: $branch_name"' |
			awk '{gsub(/\x1b\[[0-9;]*m/, "", $1); print $1}'
	)

	if [[ -n "$selected" ]]; then
		# Strip origin/ prefix if it's a remote branch for checkout
		local checkout_branch=$(echo "$selected" | sed 's|^origin/||')
		git checkout "$checkout_branch"
	else
		echo "No branch selected"
	fi
}

function export-zai() {
	if [[ -z "${ZAI_API_KEY:-}" ]]; then
		echo "export-zai: ZAI_API_KEY is not set"
		return 1
	fi

	export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
	export ANTHROPIC_MODEL="${ZAI_MODEL:-glm-5}"
	export ANTHROPIC_BASE_URL="${ZAI_BASE_URL:-https://api.z.ai/api/anthropic}"

	echo "export-zai: ANTHROPIC_* variables set for current shell"
}

function unexport-zai() {
	unset ANTHROPIC_AUTH_TOKEN
	unset ANTHROPIC_MODEL
	unset ANTHROPIC_BASE_URL

	echo "unexport-zai: ANTHROPIC_* variables cleared from current shell"
}

# Setup a 3-pane workspace in a new window
function ide() {
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

ide-aurora() {
	local branch="$1"
	local sanitized worktree_root session_name
	local aurora_repo webmono_repo aurora_worktree webmono_worktree
	local aurora_existing_branch_path webmono_existing_branch_path
	local editor_pane

	if (($# > 1)); then
		echo "Usage: ide-aurora [branch]"
		return 1
	fi

	if [[ -z "$branch" ]]; then
		read "branch?Branch name: "
	fi

	branch="${branch#origin/}"
	if [[ -z "$branch" ]]; then
		echo "ide-aurora: branch name is required"
		return 1
	fi

	if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
		echo "ide-aurora: invalid branch name: $branch"
		return 1
	fi

	sanitized=$(__git_worktree_sanitize_branch "$branch")
	if [[ -z "$sanitized" ]]; then
		echo "ide-aurora: branch name cannot produce a worktree slug"
		return 1
	fi

	aurora_repo=$(git -C "$HOME/workspace/aurora" rev-parse --show-toplevel 2>/dev/null) || {
		echo "ide-aurora: $HOME/workspace/aurora is not a git repository"
		return 1
	}
	webmono_repo=$(git -C "$HOME/workspace/webmono" rev-parse --show-toplevel 2>/dev/null) || {
		echo "ide-aurora: $HOME/workspace/webmono is not a git repository"
		return 1
	}

	worktree_root="${GIT_WORKTREE_ROOT:-$HOME/workspace/worktrees}"
	aurora_worktree="${worktree_root}/aurora__${sanitized}"
	webmono_worktree="${worktree_root}/webmono__${sanitized}"
	session_name="aurora__${sanitized}"

	if [[ -e "$aurora_worktree" ]]; then
		echo "ide-aurora: worktree already exists: $aurora_worktree"
		return 1
	fi
	if [[ -e "$webmono_worktree" ]]; then
		echo "ide-aurora: worktree already exists: $webmono_worktree"
		return 1
	fi
	if tmux has-session -t "$session_name" 2>/dev/null; then
		echo "ide-aurora: tmux session already exists: $session_name"
		return 1
	fi

	__git_worktree_fetch "$aurora_repo" "ide-aurora: aurora"
	__git_worktree_fetch "$webmono_repo" "ide-aurora: webmono"

	aurora_existing_branch_path=$(__git_worktree_branch_path "$aurora_repo" "$branch")
	if [[ -n "$aurora_existing_branch_path" ]]; then
		echo "ide-aurora: branch is already checked out for aurora: $aurora_existing_branch_path"
		return 1
	fi
	webmono_existing_branch_path=$(__git_worktree_branch_path "$webmono_repo" "$branch")
	if [[ -n "$webmono_existing_branch_path" ]]; then
		echo "ide-aurora: branch is already checked out for webmono: $webmono_existing_branch_path"
		return 1
	fi

	mkdir -p "$worktree_root" || return 1
	__git_worktree_create_branch "$aurora_repo" "$aurora_worktree" "$branch" "origin/master" || return 1
	__git_worktree_copy_local_files "$aurora_repo" "$aurora_worktree"
	__git_worktree_create_branch "$webmono_repo" "$webmono_worktree" "$branch" "origin/main" || return 1
	__git_worktree_copy_local_files "$webmono_repo" "$webmono_worktree"

	editor_pane=$(tmux new-session -d -s "$session_name" -n "aurora-code" -c "$aurora_worktree" -P -F "#{pane_id}") || return 1
	__tmux_prepare_ide_panes "$editor_pane" "$aurora_worktree" "pnpm install" || return 1
	__tmux_new_ide_window "$session_name" "webmono-code" "$webmono_worktree" "pnpm install" || return 1
	tmux select-window -t "${session_name}:aurora-code"

	if [[ -n "$TMUX" ]]; then
		tmux switch-client -t "$session_name"
	else
		tmux attach-session -t "$session_name"
	fi
}
