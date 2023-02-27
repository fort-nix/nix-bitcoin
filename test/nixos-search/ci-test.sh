#!/usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}"

# Use cachix to cache the `flake-info` build
cachixCache=nix-bitcoin

nix run .#cachix -- use "$cachixCache"

# We're running in a basic, unprivileged container that doesn't support sandboxing.
# Sandboxing is unnneeded because we're only building the 3rd-party `flake-info` tool.
echo "sandbox = false" >> /etc/nix/nix.conf

# shellcheck disable=SC2016
PATH=$(nix shell -L .#flake-info .#cachix -c sh -c 'echo $PATH')

if [[ ${CACHIX_SIGNING_KEY:-} ]]; then
    cachix push "$cachixCache" "$(type -P flake-info)";
fi

echo "Running flake-info (nixos-search)"
flake-info --json flake ../.. >/dev/null
