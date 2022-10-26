#!/usr/bin/env bash
set -euo pipefail

# Run flake-info for the nix-bitcoin flake in an offline sandbox:
# - Adds a consistent, reproducible runtime environment
# - Removes the need to trust the flake-info binary
#
# Use bubblewrap instead of a sandboxed Nix build so that we don't have to copy
# the whole repo to the sandbox when running this test.

cd "${BASH_SOURCE[0]%/*}"

nbFlake=$(realpath ../..)

# shellcheck disable=SC2016
PATH=$(nix shell -L .#{flake-info,bubblewrap} -c sh -c 'echo $PATH')

tmpDir=$(mktemp -d /tmp/nix-bitcoin-flake-info.XXX)
trap 'rm -rf $tmpDir' EXIT

echo '
experimental-features = nix-command flakes
flake-registry = /dev/null
' > "$tmpDir/nix.conf"

echo "Running flake-info (nixos-search)"

bwrap \
  --unshare-all \
  --clearenv \
  --setenv PATH "$PATH" \
  --setenv NIX_PATH "$NIX_PATH" \
  --bind "$tmpDir" / \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --ro-bind "$nbFlake" "$nbFlake" \
  --ro-bind /nix /nix \
  --ro-bind /etc /etc \
  --tmpfs /etc/nix \
  --ro-bind "$tmpDir/nix.conf" /etc/nix/nix.conf \
  --ro-bind /usr /usr \
  --ro-bind-try /run /run \
  -- flake-info --json flake "$nbFlake" >/dev/null
