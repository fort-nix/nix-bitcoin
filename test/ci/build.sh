#!/usr/bin/env bash

# This script can also be run locally for testing:
#   ./build.sh <scenario>
#
# When variable CIRRUS_CI is unset, this script leaves no persistent traces on the host system.

set -euo pipefail

scenario=$1

if [[ -v CIRRUS_CI ]]; then
    if [[ ! -e /dev/kvm ]]; then
        >&2 echo "No KVM available on VM host."
        exit 1
    fi
    # Enable KVM access for nixbld users
    chmod o+rw /dev/kvm
fi

cd "${BASH_SOURCE[0]%/*}"
exec ./build-to-cachix.sh --expr "(builtins.getFlake (toString ../..)).legacyPackages.\${builtins.currentSystem}.tests.$scenario"
