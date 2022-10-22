#!/usr/bin/env bash
set -euo pipefail

# This script uses the following env vars:
# NIX_BITCOIN_VM_ENABLE_NETWORK
# NIX_BITCOIN_VM_DATADIR
# QEMU_OPTS
# QEMU_NET_OPTS

if [[ ${NIX_BITCOIN_VM_DATADIR:-} ]]; then
    dataDir=$NIX_BITCOIN_VM_DATADIR
else
    dataDir=$(mktemp -d /tmp/nix-bitcoin-vm.XXX)
    trap 'rm -rf "$dataDir"' EXIT
fi

if [[ ! ${NIX_BITCOIN_VM_ENABLE_NETWORK:-} ]]; then
    QEMU_NET_OPTS='restrict=on'
fi

# TODO-EXTERNAL:
# Pass PATH because run-*-vm is impure (requires coreutils from PATH)
env -i \
    PATH="$PATH" \
    USE_TMPDIR=1 \
    TMPDIR="$dataDir" \
    NIX_DISK_IMAGE="$dataDir/img.qcow2" \
    QEMU_OPTS="${QEMU_OPTS:-}" \
    QEMU_NET_OPTS="${QEMU_NET_OPTS:-}" \
    "${BASH_SOURCE[0]%/*}"/run-*-vm
