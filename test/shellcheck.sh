#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/../helper/run-in-nix-env" "shellcheck findutils gnugrep" "$@"

cd "${BASH_SOURCE[0]%/*}/.."
{
    # Skip .git dir in all find commands
    find . -type f ! -path './.git/*' -name '*.sh'
    # Find files without extensions that have a shell shebang
    find . -type f ! -path './.git/*' ! -name "*.*" -exec grep -lP '\A^#! */usr/bin/env (?:nix-shell|bash)' {} \;
} | while IFS= read -r path; do
    echo "$path"
    file=${path##*/}
    dir=${path%/*}
    # Switch working directory so that shellcheck can access external sources
    # (via arg `--external-sources`)
    pushd "$dir" > /dev/null
    shellcheck --external-sources --shell bash "$file"
    popd > /dev/null
done
