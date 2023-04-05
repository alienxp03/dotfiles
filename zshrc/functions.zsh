function loop() {
  # while "$1"; do :; done
  for i in {0..10}
  do
    echo $PWD
    $1
  done
}

function s() {
  DIR="$(find ~/Workspace/ -maxdepth 2 -type d -print | cut -c 1- | fzf-tmux | head -1)"
  FOLDER="$(echo $DIR | sed 's/.*\///g')"
  echo $DIR
  echo $FOLDER
  cd $DIR
  tmux new -s $FOLDER
}
