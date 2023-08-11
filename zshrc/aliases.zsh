# Rails
alias be='bundle exec'
alias rdm='bin/rake db:migrate'
alias fs='foreman start'
alias rs='bin/rails server -b 0.0.0.0'
alias rc='bin/rails console'
alias t='bin/rspec'
alias n='bundle exec next rspec'
alias cop='bin/rubocop'
alias dstop='docker stop $(docker ps -q)'
alias go='grc go'

# Git
alias gp='git push'
alias gs='git status -u'
alias gaa='git add .'
alias gcma='git commit --amend --no-edit'
alias gcmsg='git commit -m'
alias gst='git reset --hard'
alias glo="git log --pretty=format:'%C(yellow)%h %C(green)%ad %C(yellow)%an%Cgreen%d %Creset%s' --date=format:'%I:%M:%p %d-%b-%Y'"
alias git-delete-merged-branches='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'
alias gtree="git log --graph --abbrev-commit --decorate --date=relative --format=format:'\''%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'\'' --all'''"

# Docker
alias dc='docker compose'
alias dstop='docker stop $(docker ps -a -q)'

# Bateriku
alias get_bateriku_backups='scp -r deploy@ec2-52-77-221-41.ap-southeast-1.compute.amazonaws.com:~/Backup/backups/bateriku_backup bateriku_backups'
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

alias hs='history | fzf'

# misc
alias kll='kill -9'

# golang
alias gotest='grc go test -cover -race -count=1 -v ./...'
