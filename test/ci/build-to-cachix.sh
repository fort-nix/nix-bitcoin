#!/usr/bin/env bash

# Build a single-output derivation and store it in 'cachixCache'.
# Skip the build if it is already cached.
# Accepts the same arguments as nix-instantiate.

set -euo pipefail

CACHIX_SIGNING_KEY="${CACHIX_SIGNING_KEY:-}"
cachixCache=nix-bitcoin

trap 'echo "Error at ${BASH_SOURCE[0]}:$LINENO"' ERR

tmpDir=$(mktemp -d -p /tmp)
trap 'rm -rf $tmpDir' EXIT

## Instantiate

time nix-instantiate "$@" --add-root "$tmpDir/drv" --indirect > /dev/null
drv=$(realpath "$tmpDir/drv")
echo "instantiated $drv"

outPath=$(nix-store --query "$drv")
if nix path-info --store "https://${cachixCache}.cachix.org" "$outPath" &>/dev/null; then
    echo "$outPath has already been built successfully."
    exit 0
fi

## Build

if [[ -v GITHUB_ACTIONS ]]; then
    # Avoid cachix warning message
    mkdir -p ~/.config/nix && touch ~/.config/nix/nix.conf
    cachix use "$cachixCache"
fi

if [[ $CACHIX_SIGNING_KEY ]]; then
    # Speed up task by uploading store paths as soon as they are created
    buildCmd="cachix watch-exec $cachixCache nix -- build"
else
    buildCmd="nix build"
fi

$buildCmd --out-link "$tmpDir/result" --print-build-logs "$drv^*"

if [[ $CACHIX_SIGNING_KEY ]]; then
    cachix push "$cachixCache" "$outPath"
fi

echo "$outPath"
