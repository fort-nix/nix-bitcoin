#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT
cd $TMPDIR

echo "Fetching latest release"
git clone https://github.com/elementsproject/elements 2> /dev/null
cd elements
latest=$(git describe --tags `git rev-list --tags --max-count=1`)
echo "Latest release is ${latest}"

# GPG verification
export GNUPGHOME=$TMPDIR
echo "Fetching Steven Roose's Key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys DE10E82629A8CAD55B700B972F2A88D7F8D68E87 2> /dev/null
echo "Verifying latest release"
git verify-tag ${latest}

echo "tag: ${latest}"
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256: $(git archive --format tar.gz --prefix=elements-${latest}/ ${latest} | sha256sum | cut -d\  -f1)"
