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

testDriver=$1
shift

# Variable 'tests' contains the Python code that is executed by the driver on startup
if [[ ${1:-} == --debug ]]; then
    shift
    echo "Running interactive testing environment"
    # Start REPL.
    # Use `code.interact` for the REPL instead of the builtin test driver REPL
    # because it supports low featured terminals like Emacs' shell-mode.
    tests='
is_interactive = True
exec(open(os.environ["testScript"]).read())
if "machine" in vars(): machine.start()
import code
code.interact(local=globals())
'
    echo
    echo "Starting VM, data dir: $dataDir"
else
    tests='exec(open(os.environ["testScript"]).read())'
fi

if [[ ! ${NIX_BITCOIN_VM_ENABLE_NETWORK:-} ]]; then
    QEMU_NET_OPTS='restrict=on'
fi

# The VM creates a VDE control socket in $PWD
env --chdir "$dataDir" -i \
    USE_TMPDIR=1 \
    TMPDIR="$dataDir" \
    QEMU_OPTS="-nographic ${QEMU_OPTS:-}"  \
    QEMU_NET_OPTS="${QEMU_NET_OPTS:-}" \
    "$testDriver/bin/nixos-test-driver" <(echo "$tests") "$@"
