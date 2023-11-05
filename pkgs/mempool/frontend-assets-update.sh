#!/usr/bin/env bash
set -euo pipefail

updateRepoHash() {
    repo=$1
    echo -n "Fetching latest rev for $repo: "
    hash=$(curl -fsS "https://api.github.com/repos/$repo/commits/master" | jq -r '.sha')
    echo "$hash"
    sed -i -E "s|( +)\[\"$repo(.*)|\1[\"$repo\"]=$hash|" frontend-assets-fetch.sh
}

<frontend-assets-fetch.sh sed -nE 's| +\["([^"]+).*|\1|p' | while read -r repo; do
    updateRepoHash "$repo"
done
