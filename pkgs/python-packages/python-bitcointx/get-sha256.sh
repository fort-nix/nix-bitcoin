#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/../../../helper/run-in-nix-env" "git gnupg jq" "$@"

latest=$(curl -s "https://api.github.com/repos/Simplexum/python-bitcointx/tags" | jq -r '.[0].name')
echo "Latest release is $latest"

tmpdir=$(mktemp -d /tmp/python-bitcointx-verify-gpg.XXX)
trap 'rm -rf $tmpdir' EXIT
repo=$tmpdir/repo
git clone --depth 1 --branch "$latest" -c advice.detachedHead=false https://github.com/Simplexum/python-bitcointx "$repo"

# GPG verification
export GNUPGHOME=$tmpdir
echo "Fetching Dimitry Pethukov's Key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys B17A35BBA187395784E2A6B32301D26BDC15160D 2> /dev/null
echo
echo "Verifying commit"
git -C "$repo" checkout -q "tags/$latest"
git -C "$repo" verify-commit HEAD
rm -rf "$repo"/.git
hash=$(nix hash path "$repo")

echo
echo "tag: $latest"
echo "hash: $hash"
