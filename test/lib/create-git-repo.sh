# Create and maintain a minimal git repo at the root of the copied src
(
  cd "$scriptDir/.."
  amend=--amend
  if [[ ! -e .git ]]; then
    git init
    amend=
  fi
  git add .
  if ! git diff --quiet --cached; then
    git commit -a $amend -m -
  fi
) >/dev/null
