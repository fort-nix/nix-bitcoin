#!/usr/bin/env bash

# This script can also be run locally for testing:
#   scenario=default ./build.sh
#
# When variable CIRRUS_CI is unset, this script leaves no persistent traces on the host system.

set -euo pipefail

scenario=${scenario:-}

if [[ -v CIRRUS_CI && $scenario ]]; then
    if [[ ! -e /dev/kvm ]]; then
        >&2 echo "No KVM available on VM host."
        exit 1
    fi
    # Enable KVM access for nixbld users
    chmod o+rw /dev/kvm
fi

echo "$NIX_PATH ($(nix eval --raw nixpkgs.lib.version))"

if [[ $scenario ]]; then
    buildExpr=$(../test/run-tests.sh --scenario $scenario exprForCI)
else
    buildExpr="import ./build.nix"
fi

"${BASH_SOURCE[0]%/*}/build-to-cachix.sh" -E "$buildExpr"
