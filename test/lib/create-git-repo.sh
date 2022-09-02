# Create and maintain a minimal git repo at the root of the copied src
(
  # shellcheck disable=SC2154,SC2164
  cd "$scriptDir/.."
  amend=(--amend)

  if [[ ! -e .git ]] || ! git rev-parse HEAD 2>/dev/null; then
    git init
    amend=()
  fi
  git add .
  if ! git diff --quiet --cached; then
    git commit -a "${amend[@]}" -m -
  fi
) >/dev/null
