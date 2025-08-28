function loop() {
  # while "$1"; do :; done
  for i in {0..10}
  do
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
      git for-each-ref --format='%(refname:short)	%(committerdate:relative)	%(subject)' refs/heads | \
        awk -v default="$default_branch" 'BEGIN{FS="\t"; OFS="\t"} {
          # Reconstruct the commit message from field 3 onwards
          commit_msg = $3
          for (i = 4; i <= NF; i++) {
            commit_msg = commit_msg " " $i
          }

          # Calculate padding needed for alignment (assuming max branch name + date is around 50 chars)
          branch_date = $1 " (" $2 ")"
          padding = 50 - length(branch_date)
          if (padding < 1) padding = 1
          spaces = sprintf("%" padding "s", "")

          if ($1 == default) {
            printf "\033[34m%s\033[0m \033[92m(%s)\033[0m%s%s\n", $1, $2, spaces, commit_msg
          } else {
            printf "\033[33m%s\033[0m \033[92m(%s)\033[0m%s%s\n", $1, $2, spaces, commit_msg
          }
        }'

      git for-each-ref --format='%(refname:short)	%(committerdate:relative)	%(subject)' refs/remotes | \
        awk 'BEGIN{FS="\t"; OFS="\t"} {
          # Reconstruct the commit message from field 3 onwards
          commit_msg = $3
          for (i = 4; i <= NF; i++) {
            commit_msg = commit_msg " " $i
          }

          # Calculate padding needed for alignment (assuming max branch name + date is around 50 chars)
          branch_date = $1 " (" $2 ")"
          padding = 50 - length(branch_date)
          if (padding < 1) padding = 1
          spaces = sprintf("%" padding "s", "")

          printf "\033[38;5;208m%s\033[0m \033[92m(%s)\033[0m%s%s\n", $1, $2, spaces, commit_msg
        }'
    } | \
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
      --preview 'branch_name=$(echo {} | awk "{print \$1}" | sed "s/\x1b\[[0-9;]*m//g"); git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" "$branch_name" -- 2>/dev/null | head -20 || echo "No commits found for branch: $branch_name"' | \
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

