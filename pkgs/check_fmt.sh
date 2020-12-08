#!/usr/bin/env bash

test_fmt() {
  hash nixfmt 2>&- || { echo >&2 "nixfmt not in PATH."; exit 1; }
  IFS='
'
  for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.nix$'); do
    output=$(git cat-file -p :"$file" | nixfmt -c 2>&1)
    if test $? -ne 0; then
      output=$("${output/<stdin>/$file}")
      syntaxerrors="${list}${output}"
    elif test -n "$output"; then
      list="${list}${file}\n"
    fi
  done

  exitcode=0
  if test -n "$syntaxerrors"; then
    echo >&2 "nixfmt found syntax errors:"
    echo "$syntaxerrors"
    exitcode=1
  fi

  if test -n "$list"; then
    echo >&2 "nixfmt needs to format these files (run nixfmt and git add):"
    echo "$list"
    exitcode=1
  fi
  exit $exitcode
}

case "$1" in
  --about )
    echo "Check Nix code formatting"
    ;;
  * )
    test_fmt
    ;;
esac
