#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/../../helper/run-in-nix-env" "git" "$@"

archive_hash () {
    repo=$1
    rev=$2
    nix-prefetch-url --unpack "https://github.com/${repo}/archive/${rev}.tar.gz" 2> /dev/null | tail -n 1
}

echo "Fetching latest lightningd/plugins release"
latest=$(git ls-remote https://github.com/lightningd/plugins master | cut -f 1)
echo "rev = \"${latest}\";"
echo "sha256 = \"$(archive_hash lightningd/plugins "$latest")\";"
