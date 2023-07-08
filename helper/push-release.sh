#!/usr/bin/env bash
set -euo pipefail

REPO=fort-nix/nix-bitcoin
BRANCH=master
GIT_REMOTE=origin
OAUTH_TOKEN=
DRY_RUN=
releaseVersion=

trap 'echo "Error at ${BASH_SOURCE[0]}:$LINENO"' ERR

cd "${BASH_SOURCE[0]%/*}"

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=1
            ;;
        *)
            releaseVersion="$arg"
            ;;
    esac
done

latestVersion=$(curl -fsS https://api.github.com/repos/$REPO/releases/latest | jq -r '.tag_name' | tail -c +2)

if [[ ! $releaseVersion ]]; then
    # Increment the lowest/last part of `latestVersion`
    releaseVersion=$(echo "$latestVersion" | awk -F. '/[0-9]+\./{$NF++;print}' OFS=.)
fi

if [[ $DRY_RUN ]]; then
    echo "Dry run"
else
    OAUTH_TOKEN=$(pass show nix-bitcoin/github/oauth-token)
    if [[ ! $OAUTH_TOKEN ]]; then
        echo "Error fetching OAUTH_TOKEN"
        exit 1
    fi
fi

echo "Latest release: $latestVersion"

if [[ ! $DRY_RUN ]]; then
   while true; do
       read -rp "Create release ${releaseVersion}? [yn] " yn
       case $yn in
           [Yy]* ) break;;
           [Nn]* ) exit;;
           * ) echo "Please answer y or n.";;
       esac
   done
fi

nixosVersion=$(sed -nE 's|.*system.stateVersion = "(.*?)".*|\1|p' ../examples/configuration.nix)
if [[ ! $nixosVersion ]]; then
    echo "Error fetching NixOS version"
    exit 1
fi
nixosVersionBranch=nixos-$nixosVersion

TMPDIR=$(mktemp -d)
if [[ ! $DRY_RUN ]]; then trap 'rm -rf $TMPDIR' EXIT; fi
ARCHIVE_NAME=nix-bitcoin-$releaseVersion.tar.gz
ARCHIVE=$TMPDIR/$ARCHIVE_NAME

# Need to be in the repo root directory for archiving
(cd "$(git rev-parse --show-toplevel)"; git archive --format=tar.gz -o "$ARCHIVE" "$BRANCH")

SHA256SUMS=$TMPDIR/SHA256SUMS.txt
# Use relative path with sha256sums because it'll output the first
# argument
(cd "$TMPDIR"; sha256sum "$ARCHIVE_NAME" > "$SHA256SUMS")
gpg -o "$SHA256SUMS.asc" -a --detach-sig "$SHA256SUMS"

pushd "$TMPDIR" >/dev/null

nix hash to-sri --type sha256 "$(nix-prefetch-url --unpack "file://$ARCHIVE" 2> /dev/null)" > nar-hash.txt
gpg -o nar-hash.txt.asc -a --detach-sig nar-hash.txt

if [[ $DRY_RUN ]]; then
    echo "Created v$releaseVersion in $TMPDIR"
    echo "NixOS version branch: $nixosVersionBranch"
    exit 0
fi

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Create release

POST_DATA="{ \"tag_name\": \"v$releaseVersion\", \"name\": \"nix-bitcoin-$releaseVersion\", \"body\": \"nix-bitcoin-$releaseVersion\", \"target_comitish\": \"$BRANCH\" }"
RESPONSE=$(curl -fsS -H "Authorization: token $OAUTH_TOKEN" -d "$POST_DATA" https://api.github.com/repos/$REPO/releases)
ID=$(echo "$RESPONSE" | jq -r '.id')
if [[ $ID == null ]]; then
    echo "Failed to create release with $POST_DATA"
    exit 1
fi

post_asset() {
    GH_ASSET="https://uploads.github.com/repos/$REPO/releases/$ID/assets?name="
    curl -fsS -H "Authorization: token $OAUTH_TOKEN" --data-binary "@$1" -H "Content-Type: application/octet-stream" \
         "$GH_ASSET/$(basename "$1")"
}
post_asset nar-hash.txt
post_asset nar-hash.txt.asc
# Post additional assets for backwards compatibility.
# This allows older nix-bitcoin installations to upgrade via `fetch-release`.
post_asset "$ARCHIVE"
post_asset "$SHA256SUMS"
post_asset "$SHA256SUMS.asc"

popd >/dev/null

if [[ ! $DRY_RUN ]]; then
    git push "$GIT_REMOTE" "$BRANCH:release"
    git push "$GIT_REMOTE" "$BRANCH:$nixosVersionBranch"
fi

echo "Successfully created" "$(echo "$POST_DATA" | jq -r .tag_name)"
