# Rails
alias be='bundle exec'
alias rdm='bin/rake db:migrate'
alias fs='foreman start'
alias rs='bin/rails server -b 0.0.0.0'
alias rc='bin/rails console'
alias n='bundle exec next rspec'
alias cop='bin/rubocop'
alias dstop='docker stop $(docker ps -q)'

# Git
alias gp='git push'
alias gs='git status -u'
alias gcb='git branch | grep -v "^\*" | fzf --reverse --info=inline | xargs git checkout'
alias gcm='git checkout master 2>/dev/null || git checkout main'
alias gaa='git add .'
alias gcma='git commit --amend --no-edit'
alias gcmsg='git commit -m'
alias gst='git reset --hard'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias glo="git log --pretty=format:'%C(yellow)%h %C(green)%ad %C(yellow)%an%Cgreen%d %Creset%s' --date=format:'%I:%M:%p %d-%b-%Y'"
alias git-delete-merged-branches='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'
alias gtree="git log --graph --abbrev-commit --decorate --date=relative --format=format:'\''%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'\'' --all'''"
alias lz='lazygit'
# alias greset="git reset $(git merge-base master $(git rev-parse --abbrev-ref HEAD)) " # reset all commits in branch

# Docker
alias dc='docker compose'
alias dstop='docker stop $(docker ps -a -q)'
alias mk='minikube'
alias docker-clean='docker container rm $(docker container ls -aq) 2>/dev/null && docker images | grep "<none>" | awk '{print $3}' | xargs docker rmi'
alias kl='kubectl'

# Bateriku
alias bateriku_production='ssh deploy@$(bundle exec cap production ec2:status | grep "bateriku-production-1" -m 1| tr -s " " | cut -d " " -f6)'
alias bateriku_production2='ssh deploy@$(bundle exec cap production ec2:status | grep "bateriku-production-2" -m 1| tr -s " " | cut -d " " -f6)'
alias bateriku_staging='ssh -t deploy@$(bundle exec cap staging ec2:status | grep "bateriku-staging" -m 1| tr -s " " | cut -d " " -f6) "cd /var/www/bateriku/current; bash --login" '
alias baterikucom="ssh root@bateriku.com -p 37017"

alias sub=subl

# tmux/nvim
alias tx='tmux attach-session'
alias tn="tmux new -s $(pwd | sed 's/.*\///g')"
alias v='nvim'
alias xx='exit'

# misc
alias kll='kill -9'

# golang
alias gmt='go mod tidy -v'
alias gmv='go mod vendor -v'
alias gotest='go test -v --count=1'

# terraform
alias tf='terraform'

# why not
alias ls='eza --group-directories-first --sort extension'
alias cat='bat'

alias t='sesh connect $(sesh list | fzf)'
