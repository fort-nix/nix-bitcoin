#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/../../../helper/run-in-nix-env" "git gnupg" "$@"

TMPDIR=$(mktemp -d -p /tmp)
trap 'rm -rf $TMPDIR' EXIT
cd "$TMPDIR"

echo "Fetching latest release"
git clone https://github.com/simplexum/python-bitcointx 2> /dev/null
cd python-bitcointx
latest=python-bitcointx-v1.1.3
echo "Latest release is ${latest}"

# GPG verification
export GNUPGHOME=$TMPDIR
echo "Fetching Dimitry Pethukov's Key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys B17A35BBA187395784E2A6B32301D26BDC15160D 2> /dev/null
echo "Verifying latest release"
git verify-commit "$latest"

echo "tag: $latest"
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256: $(git archive --format tar.gz --prefix=python-bitcointx-"$latest"/ "$latest" | sha256sum | cut -d\  -f1)"
