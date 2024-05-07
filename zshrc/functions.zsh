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
