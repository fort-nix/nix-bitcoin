#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg curl jq
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT
cd $TMPDIR

echo "Fetching latest release"
repo=fiatjaf/trustedcoin
latest=$(curl -s --show-error https://api.github.com/repos/$repo/releases/latest | jq -r .tag_name)
echo "Latest release is $latest"
git clone --depth 1 --branch $latest https://github.com/fiatjaf/trustedcoin 2>/dev/null
cd trustedcoin

echo "tag: $latest"
git checkout -q tags/$latest
rm -rf .git
nix --extra-experimental-features nix-command hash path .
