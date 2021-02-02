#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT
cd $TMPDIR

echo "Fetching latest release"
git clone https://github.com/lightninglabs/faraday 2> /dev/null
cd faraday
latest=$(git describe --tags `git rev-list --tags --max-count=1`)
echo "Latest release is ${latest}"


# GPG verification
export GNUPGHOME=$TMPDIR
echo "Fetching Calra Kirk Cohen's Key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 15E7ECF257098A4EF91655EB4CA7FE54A6213C91 2> /dev/null

echo "Verifying latest release"
git verify-tag ${latest}

echo "tag: ${latest}"
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256: $(git archive --format tar.gz --prefix=faraday-${latest//v}/ ${latest} | sha256sum | cut -d\  -f1)"
