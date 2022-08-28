#!/usr/bin/env bash

# This script can also be run locally for testing:
#   scenario=default ./build.sh
#
# When variable CIRRUS_CI is unset, this script leaves no persistent traces on the host system.

set -euo pipefail

if [[ -v CIRRUS_CI ]]; then
    if [[ ! -e /dev/kvm ]]; then
        >&2 echo "No KVM available on VM host."
        exit 1
    fi
    # Enable KVM access for nixbld users
    chmod o+rw /dev/kvm
fi

# shellcheck disable=SC2154
"${BASH_SOURCE[0]%/*}/../run-tests.sh" --ci --scenario "$scenario"
