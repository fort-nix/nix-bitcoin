#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git gnupg jq

set -euo pipefail
newVersion=$(curl -s "https://api.github.com/repos/joinmarket-org/joinmarket-clientserver/releases" | jq -r '.[0].tag_name')

# Fetch release and GPG-verify the content hash
tmpdir=$(mktemp -d /tmp/joinmarket-verify-gpg.XXX)
repo=$tmpdir/repo
git clone --depth 1 --branch "${newVersion}" -c advice.detachedHead=false https://github.com/joinmarket-org/joinmarket-clientserver "$repo"
export GNUPGHOME=$tmpdir
echo "Fetching Adam Gibson's key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 2B6FC204D9BF332D062B461A141001A1AF77F20B 2> /dev/null
echo
echo "Verifying commit"
git -C "$repo" verify-commit HEAD
rm -rf "$repo"/.git
newHash=$(nix hash path "$repo")
rm -rf "$tmpdir"
echo

echo "tag: $newVersion"
echo "hash: $newHash"
