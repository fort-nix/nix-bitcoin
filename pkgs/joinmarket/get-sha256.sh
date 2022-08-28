#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap 'rm -rf $TMPDIR' EXIT
cd "$TMPDIR"

echo "Fetching latest release"
git clone https://github.com/joinmarket-org/joinmarket-clientserver 2> /dev/null
cd joinmarket-clientserver
latest=$(git describe --tags "$(git rev-list --tags --max-count=1)")
echo "Latest release is $latest"

# GPG verification
export GNUPGHOME=$TMPDIR
echo "Fetching Adam Gibson's key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 2B6FC204D9BF332D062B461A141001A1AF77F20B 2> /dev/null
echo "Verifying latest release"
git verify-tag "$latest"

echo "tag: $latest"
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256: $(nix-hash --type sha256 --flat --base32 \
                <(git archive --format tar.gz --prefix=joinmarket-clientserver-"${latest//v}"/ "$latest"))"
