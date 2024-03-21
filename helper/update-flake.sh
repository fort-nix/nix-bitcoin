#!/usr/bin/env bash
set -euo pipefail

# This script does the following:
# - Update all flake inputs, including nixpkgs
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

# Support Nix >2.18
{
    versionGreaterThan() {
        [[ $1 != $(echo -e "$1\n$2" | sort -V | head -n1) ]]
    }
    nixVersion=$(nix --version | cut -d\  -f 3)
    if versionGreaterThan "$nixVersion" 2.18; then
        # https://nixos.org/manual/nix/stable/release-notes/rl-2.19#:~:text=nix%20flake%20update
        nixUpdateArg=--flake
    else
        nixUpdateArg=
    fi
}

echo "Updating flake 'nixos-search'"
nix flake update $nixUpdateArg ../test/nixos-search
echo

versions=$(nix eval --json -f update-flake.nix versions)

## Uncomment the following to generate a version change message for testing
# versions=$(echo "$versions" | sed 's|1|0|g')

echo "Updating main flake"
if [[ $nixosVersion ]]; then
    sed -Ei "s|(nixpkgs.url = .*nixos-)[^\"]+|\1$nixosVersion|" ../flake.nix
fi
nix flake update $nixUpdateArg ..

echo
nix eval --raw -f update-flake.nix --argstr prevVersions "$versions" showUpdates; echo

pinned=../pkgs/pinned.nix
pinnedSrc=$(nix eval --raw -f update-flake.nix --argstr prevVersions "$versions" pinnedFile)
if [[ $pinnedSrc != $(cat "$pinned") ]]; then
    echo "$pinnedSrc" > "$pinned"
    echo
    echo "Updated pinned.nix"
fi
