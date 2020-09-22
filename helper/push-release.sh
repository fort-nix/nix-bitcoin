#!/usr/bin/env bash
set -euo pipefail

REPO=fort-nix/nix-bitcoin
BRANCH=master
OAUTH_TOKEN=$(pass show nix-bitcoin/github/oauth-token)
DRY_RUN=
TAG_NAME=

if [[ ! $OAUTH_TOKEN ]]; then
    echo "Please set OAUTH_TOKEN variable"
fi

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=1
            ;;
        *)
            TAG_NAME="$arg"
            ;;
    esac
done

if [[ ! $TAG_NAME ]]; then
    echo "$0 [--dry-run|-n] <tag_name>"
    exit
fi
if [[ $DRY_RUN ]]; then echo "Dry run"; fi

RESPONSE=$(curl https://api.github.com/repos/$REPO/releases/latest 2> /dev/null)
echo "Latest release" $(echo $RESPONSE | jq -r '.tag_name' | tail -c +2)
while true; do
    read -p "Create release $TAG_NAME? [yn] " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done

TMPDIR=$(mktemp -d)
if [[ ! $DRY_RUN ]]; then trap "rm -rf $TMPDIR" EXIT; fi
ARCHIVE_NAME=nix-bitcoin-$TAG_NAME.tar.gz
ARCHIVE=$TMPDIR/$ARCHIVE_NAME

# Need to be in the repositories root directory for archiving
(cd $(git rev-parse --show-toplevel); git archive --format=tar.gz -o $ARCHIVE $BRANCH)

SHA256SUMS=$TMPDIR/SHA256SUMS.txt
# Want to use relative path with sha256sums because it'll output the first
# argument
(cd $TMPDIR; sha256sum $ARCHIVE_NAME > $SHA256SUMS)
gpg -o $SHA256SUMS.asc -a --detach-sig $SHA256SUMS

if [[ $DRY_RUN ]]; then
    echo "Created v$TAG_NAME in $TMPDIR"
    exit 0
fi

POST_DATA="{ \"tag_name\": \"v$TAG_NAME\", \"name\": \"nix-bitcoin-$TAG_NAME\", \"body\": \"nix-bitcoin-$TAG_NAME\", \"target_comitish\": \"$BRANCH\" }"
RESPONSE=$(curl -H "Authorization: token $OAUTH_TOKEN" -d "$POST_DATA" https://api.github.com/repos/$REPO/releases 2> /dev/null)
ID=$(echo $RESPONSE | jq -r '.id')
if [[ $ID == null ]]; then
    echo "Failed to create release with $POST_DATA"
    exit 1
fi

post_asset() {
    GH_ASSET="https://uploads.github.com/repos/$REPO/releases/$ID/assets?name="
    curl -H "Authorization: token $OAUTH_TOKEN" --data-binary "@$TAG_NAME" -H "Content-Type: application/octet-stream" \
         $GH_ASSET/$(basename $TAG_NAME) &> /dev/null
}
post_asset $ARCHIVE
post_asset $SHA256SUMS
post_asset $SHA256SUMS.asc
echo "Successfully created" $(echo $POST_DATA | jq -r .tag_name)
