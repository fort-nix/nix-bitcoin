#!/usr/bin/env bash
set -euo pipefail

REPO=fort-nix/nix-bitcoin
BRANCH=master
OAUTH_TOKEN=$(pass show nix-bitcoin/github/oauth-token)

if [[ ! $OAUTH_TOKEN ]]; then
    echo "Please set OAUTH_TOKEN variable"
fi

if [[ $# < 1 ]]; then
    echo "$0 <tag_name>"
    exit
fi
TAG_NAME=$1

RESPONSE=$(curl https://api.github.com/repos/$REPO/releases/latest 2> /dev/null)
echo "Latest release" $(echo $RESPONSE | jq -r '.tag_name' | tail -c +2)
while true; do
    read -p "Create release $1? [yn] " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
ARCHIVE_NAME=nix-bitcoin-$TAG_NAME.tar.gz
ARCHIVE=$TMPDIR/$ARCHIVE_NAME

# Need to be in the repositories root directory for archiving
(cd $(git rev-parse --show-toplevel); git archive --format=tar.gz -o $ARCHIVE $BRANCH)

SHA256SUMS=$TMPDIR/SHA256SUMS.txt
# Want to use relative path with sha256sums because it'll output the first
# argument
(cd $TMPDIR; sha256sum $ARCHIVE_NAME > $SHA256SUMS)
gpg -o $SHA256SUMS.asc -a --detach-sig $SHA256SUMS

POST_DATA="{ \"tag_name\": \"v$TAG_NAME\", \"name\": \"nix-bitcoin-$TAG_NAME\", \"body\": \"nix-bitcoin-$TAG_NAME\", \"target_comitish\": \"$BRANCH\" }"
RESPONSE=$(curl -H "Authorization: token $OAUTH_TOKEN" -d "$POST_DATA" https://api.github.com/repos/$REPO/releases 2> /dev/null)
ID=$(echo $RESPONSE | jq -r '.id')
if [[ $ID == null ]]; then
    echo "Failed to create release with $POST_DATA"
    exit 1
fi

post_asset() {
    GH_ASSET="https://uploads.github.com/repos/$REPO/releases/$ID/assets?name="
    curl -H "Authorization: token $OAUTH_TOKEN" --data-binary "@$1" -H "Content-Type: application/octet-stream" \
         $GH_ASSET/$(basename $1) &> /dev/null
}
post_asset $ARCHIVE
post_asset $SHA256SUMS
post_asset $SHA256SUMS.asc
echo "Successfully created" $(echo $POST_DATA | jq -r .tag_name)
