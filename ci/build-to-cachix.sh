#!/usr/bin/env bash

# Build a single-output derivation and store it in 'cachixCache'.
# Skip the build if it is already cached.
# Accepts the same arguments as nix-instantiate.

set -euo pipefail

CACHIX_SIGNING_KEY=${CACHIX_SIGNING_KEY:-}
cachixCache=nix-bitcoin

trap 'echo Error at line $LINENO' ERR

atExit() {
    rm -rf $tmpDir
    if [[ -v cachixPid ]]; then kill $cachixPid; fi
}
tmpDir=$(mktemp -d -p /tmp)
trap atExit EXIT

## Instantiate

time nix-instantiate "$@" --add-root $tmpDir/drv --indirect > /dev/null
printf "instantiated "; realpath $tmpDir/drv

outPath=$(nix-store --query $tmpDir/drv)
if nix path-info --store https://$cachixCache.cachix.org $outPath &>/dev/null; then
    echo "$outPath has already been built successfully."
    exit 0
fi

## Build

if [[ -v CIRRUS_CI ]]; then
    cachix use $cachixCache
fi

if [[ $CACHIX_SIGNING_KEY ]]; then
    # Speed up task by uploading store paths as soon as they are created
    cachix push $cachixCache --watch-store &
    cachixPid=$!
fi

nix-build --out-link $tmpDir/result $tmpDir/drv >/dev/null

if [[ $CACHIX_SIGNING_KEY ]]; then
    cachix push $cachixCache $outPath
fi

echo $outPath
