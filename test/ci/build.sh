#!/usr/bin/env bash

# This script can also be run locally for testing:
#   ./build.sh <scenario>
#
# When variable GITHUB_ACTIONS is unset, this script leaves no persistent traces on the host system.

set -euo pipefail

scenario=$1

if [[ -v GITHUB_ACTIONS ]]; then
    if [[ ! -e /dev/kvm ]]; then
        >&2 echo "No KVM available on VM host."
        exit 1
    fi
fi

cd "${BASH_SOURCE[0]%/*}"
exec ./build-to-cachix.sh --expr "(builtins.getFlake (toString ../..)).legacyPackages.\${builtins.currentSystem}.tests.$scenario"
