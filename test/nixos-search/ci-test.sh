#!/usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}"

nbFlake=$(realpath ../..)

# Use cachix to cache the `flake-info` build
cachixCache=nix-bitcoin

nix run .#cachix -- use "$cachixCache"

# shellcheck disable=SC2016
PATH=$(nix shell -L .#{flake-info,cachix,jq} -c sh -c 'echo $PATH')

# flake-info uses `nixpkgs` from NIX_PATH
NIX_PATH="nixpkgs=$(nix flake metadata --json --inputs-from "$nbFlake" nixpkgs | jq -r .path)"
export NIX_PATH

if [[ ${CACHIX_SIGNING_KEY:-} ]]; then
    cachix push "$cachixCache" "$(type -P flake-info)";
fi

echo "Running flake-info (nixos-search)"
flake-info --json flake ../.. >/dev/null
