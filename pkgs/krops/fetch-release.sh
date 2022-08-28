#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git
set -euo pipefail

archive_hash () {
    repo=$1
    rev=$2
    nix-prefetch-url --unpack "https://github.com/${repo}/archive/${rev}.tar.gz" 2> /dev/null
}

echo "Fetching latest version"
version=$(
  git ls-remote --tags https://github.com/krebs/krops | cut -f 2 \
    | sed -E 's|refs/tags/||g; s|((v)?(.*))|\1 \3|g' | sort -k 2 -V | tail -1 | cut -f 1 -d' '
)
echo "rev: ${version}"
echo "sha256: $(archive_hash krebs/krops "$version")"
