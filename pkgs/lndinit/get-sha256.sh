#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/../../helper/run-in-nix-env" "git gnupg curl jq" "$@"

TMPDIR=$(mktemp -d -p /tmp)
trap 'rm -rf $TMPDIR' EXIT
cd "$TMPDIR"

echo "Fetching latest release"
repo=lightninglabs/lndinit
latest=$(curl -fsS "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)
echo "Latest release is $latest"
git clone --depth 1 --branch "$latest" https://github.com/lightninglabs/lndinit 2>/dev/null
cd lndinit

# GPG verification
export GNUPGHOME=$TMPDIR
echo "Fetching Oliver Gugger's key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys F4FC70F07310028424EFC20A8E4256593F177720 2> /dev/null
echo "Verifying latest release"
git verify-tag "$latest"

echo "tag: $latest"
git checkout -q "tags/$latest"
rm -rf .git
nix hash path .
