#!/usr/bin/env bash
set -euo pipefail

# Fetch hash-locked versions of assets that are dynamically fetched via
# https://github.com/mempool/mempool/blob/master/frontend/sync-assets.js
# when running `npm run build` in the frontend.
#
# This file is updated by ./frontend-assets-update.sh

declare -A revs=(
    ["mempool/mining-pool-logos"]=53972ebbd08373cf4910cbb3e6421a1f3bba4563
)

fetchFile() {
    repo=$1
    file=$2
    rev=${revs["$repo"]}
    curl -fsS "https://raw.githubusercontent.com/$repo/$rev/$file"
}

fetchRepo() {
    repo=$1
    rev=${revs["$repo"]}
    curl -fsSL "https://github.com/$repo/archive/$rev.tar.gz"
}

mkdir mining-pools
fetchRepo "mempool/mining-pool-logos" | tar xz --strip-components=1 -C mining-pools
