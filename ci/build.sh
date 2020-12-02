#!/usr/bin/env bash

# This script can also be run locally for testing:
#   scenario=default ./build.sh
#
# WARNING: This script fetches contents from an untrusted $cachixCache to your local nix-store.
#
# When variable CIRRUS_CI is unset, this script leaves no persistent traces on the host system.

set -euo pipefail

scenario=${scenario:-}
CACHIX_SIGNING_KEY=${CACHIX_SIGNING_KEY:-}
cachixCache=nix-bitcoin

trap 'echo Error at line $LINENO' ERR

if [[ -v CIRRUS_CI ]]; then
    tmpDir=/tmp
    if [[ $scenario ]]; then
        if [[ ! -e /dev/kvm ]]; then
            >&2 echo "No KVM available on VM host."
            exit 1
        fi
        # Enable KVM access for nixbld users
        chmod o+rw /dev/kvm
    fi
else
    atExit() {
        rm -rf $tmpDir
        if [[ -v cachixPid ]]; then kill $cachixPid; fi
    }
    tmpDir=$(mktemp -d -p /tmp)
    trap atExit EXIT
    # Prevent cachix from writing to HOME
    export HOME=$tmpDir
fi

cachix use $cachixCache
cd "${BASH_SOURCE[0]%/*}"

## Build

echo "$NIX_PATH ($(nix eval --raw nixpkgs.lib.version))"

if [[ $scenario ]]; then
    buildExpr=$(../test/run-tests.sh --scenario $scenario exprForCI)
else
    buildExpr="import ./build.nix"
fi

time nix-instantiate -E "$buildExpr" --add-root $tmpDir/drv --indirect > /dev/null
printf "instantiated "; realpath $tmpDir/drv

outPath=$(nix-store --query $tmpDir/drv)
if nix path-info --store https://$cachixCache.cachix.org $outPath &>/dev/null; then
    echo "$outPath" has already been built successfully.
    exit 0
fi

# Cirrus doesn't expose secrets to pull-request builds,
# so skip cache uploading in this case
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
