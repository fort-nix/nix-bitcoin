#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT
cd $TMPDIR

echo "Fetching latest release"
git clone https://github.com/lightninglabs/pool 2> /dev/null
cd pool
latest=$(git describe --tags `git rev-list --tags --max-count=1`)
echo "Latest release is ${latest}"

# GPG verification
export GNUPGHOME=$TMPDIR
echo "Fetching Olaoluwa Osuntokun's key"
gpg --keyserver hkps://keys.openpgp.org --recv-keys 60A1FA7DA5BFF08BDCBBE7903BBD59E99B280306 2> /dev/null
echo "Fetching Oliver Gugger's key"
gpg --keyserver hkps://keys.openpgp.org --recv-keys F4FC70F07310028424EFC20A8E4256593F177720 2> /dev/null

echo "Verifying latest release"
git verify-tag ${latest}

echo "tag: ${latest}"
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256: $(git archive --format tar.gz --prefix=pool-${latest//v}/ ${latest} | sha256sum | cut -d\  -f1)"
