#!/usr/bin/env bash
set -euo pipefail

# This script does the following:
# - When called without arguments, update all flake inputs, including nixpkgs.
# - When called with a version argument, set input `nixpkgs` in `flake.nix` to the
#   specified version and only update this input.
# - Print version updates of pinned pkgs like so:
#     Pkg updates in nixpkgs unstable:
#     bitcoin: 0.20.0 -> 0.21.1
#     btcpayserver: 1.1.0 -> 1.1.2
# - Write ../pkgs/pinned.nix:
#     Packages for which the stable und unstable versions are identical are
#     pinned to stable.
#     All other pkgs are pinned to unstable.

forceRun=
nixosVersion=
for arg in "$@"; do
    case $arg in
        -f)
            forceRun=1
            ;;
        *)
            nixosVersion=$arg
            ;;
    esac
done

# cd to script dir
cd "${BASH_SOURCE[0]%/*}"

if [[ $(nix flake 2>&1) != *"requires a sub-command"* ]]; then
    echo "Error. This script requires nix flake support."
    echo "https://nixos.wiki/wiki/Flakes#Installing_flakes"
    exit 1
fi

if [[ $forceRun ]] && ! git diff --quiet ../flake.{nix,lock}; then
    echo "error: flake.nix/flake.lock have changes. Run with option -f to ignore."
    exit 1
fi

if [[ ! $nixosVersion ]]; then
    echo "Updating flake 'nixos-search'"
    nix flake update --flake ../test/nixos-search
    echo
fi

versions=$(nix eval --json -f update-flake.nix versions)

## Uncomment the following to generate a version change message for testing
# versions=$(echo "$versions" | sed 's|1|0|g')

setVersion() {
    sed -Ei "s|($1)[0-9.]+|\1$nixosVersion|" "$2"
}

echo "Updating main flake"
if [[ $nixosVersion ]]; then
    setVersion 'nixpkgs.url = .*?nixos-' ../flake.nix
    setVersion 'system.stateVersion = "' ../examples/configuration.nix
    setVersion 'nix-bitcoin.url = .*?/nixos-' ../examples/flakes/flake.nix
    setVersion 'nix-bitcoin.url = .*?/nixos-' ../examples/container/flake.nix
    setVersion 'update-flake.sh ' ../dev/README.md
    nix flake update nixpkgs --flake ..
else
    nix flake update --flake ..
fi

echo
nix eval --raw -f update-flake.nix --argstr prevVersions "$versions" showUpdates; echo

pinned=../pkgs/pinned.nix
pinnedSrc=$(nix eval --raw -f update-flake.nix --argstr prevVersions "$versions" pinnedFile)
if [[ $pinnedSrc != $(cat "$pinned") ]]; then
    echo "$pinnedSrc" > "$pinned"
    echo
    echo "Updated pinned.nix"
fi
