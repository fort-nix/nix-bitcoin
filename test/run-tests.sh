#!/usr/bin/env bash

# Modules integration test runner.
# The tests (./tests.nix) use the NixOS testing framework and are executed in a VM.
#
# Usage:
#   Run all tests
#   ./run-tests.sh
#
#   Test specific scenario
#   ./run-tests.sh --scenario|-s <scenario>
#
#     When <scenario> is undefined, the test is run with an adhoc scenario
#     where services.<scenario> is enabled.
#
#   Run test and link results to avoid garbage collection
#   ./run-tests.sh [--scenario <scenario>] --out-link-prefix /tmp/nix-bitcoin-test build
#
#   Pass extra args to nix-build
#   ./run-tests.sh build --builders 'ssh://mybuildhost - - 15'
#
#   Run interactive test debugging
#   ./run-tests.sh [--scenario <scenario>] debug
#
#     This starts the testing VM and drops you into a Python REPL where you can
#     manually execute the tests from ./tests.py
#
#   To add custom scenarios, set the environment variable `scenarioOverridesFile`.

set -eo pipefail

scenario=
outLinkPrefix=
while :; do
    case $1 in
        --scenario|-s)
            if [[ $2 ]]; then
                scenario=$2
                shift
                shift
            else
                >&2 echo "Error: $1 requires an argument."
                exit 1
            fi
            ;;
        --out-link-prefix|-o)
            if [[ $2 ]]; then
                outLinkPrefix=$2
                shift
                shift
            else
                >&2 echo "Error: $1 requires an argument."
                exit 1
            fi
            ;;
        *)
            break
    esac
done

numCPUs=${numCPUs:-$(nproc)}
# Min. 800 MiB needed to avoid 'out of memory' errors
memoryMiB=${memoryMiB:-2048}

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

export NIX_PATH=nixpkgs=$(nix eval --raw -f "$scriptDir/../pkgs/nixpkgs-pinned.nix" nixpkgs)

# Run the test. No temporary files are left on the host system.
run() {
    # TMPDIR is also used by the test driver for VM tmp files
    export TMPDIR=$(mktemp -d /tmp/nix-bitcoin-test.XXX)
    trap "rm -rf $TMPDIR" EXIT

    nix-build --out-link $TMPDIR/driver -E "(import \"$scriptDir/tests.nix\" { scenario = \"$scenario\"; }).vm" -A driver

    # Variable 'tests' contains the Python code that is executed by the driver on startup
    if [[ $1 == --interactive ]]; then
        echo "Running interactive testing environment"
        tests=$(
            echo 'is_interactive = True'
            echo 'exec(os.environ["testScript"])'
            # Start VM
            echo 'start_all()'
            # Start REPL
            echo 'import code'
            echo 'code.interact(local=globals())'
        )
    else
        tests='exec(os.environ["testScript"])'
    fi

    echo "VM stats: CPUs: $numCPUs, memory: $memoryMiB MiB"
    [[ $NB_TEST_ENABLE_NETWORK ]] || QEMU_NET_OPTS='restrict=on'
    cd $TMPDIR # The VM creates a VDE control socket in $PWD
    env -i \
        NIX_PATH="$NIX_PATH" \
        TMPDIR="$TMPDIR" \
        USE_TMPDIR=1 \
        NIX_DISK_IMAGE=$TMPDIR/img.qcow2 \
        tests="$tests" \
        QEMU_OPTS="-smp $numCPUs -m $memoryMiB -nographic $QEMU_OPTS"  \
        QEMU_NET_OPTS="$QEMU_NET_OPTS" \
        $TMPDIR/driver/bin/nixos-test-driver
}

debug() {
    run --interactive
}

# Run the test by building the test derivation
buildTest() {
    if [[ $outLinkPrefix ]]; then
        buildArgs="--out-link $outLinkPrefix-$scenario"
    else
        buildArgs=--no-out-link
    fi
    vmTestNixExpr | nix-build $buildArgs "$@" -
}

# On continuous integration nodes there are few other processes running alongside the
# test, so use more memory here for maximum performance.
exprForCI() {
    memoryMiB=3072
    memTotalKiB=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
    memAvailableKiB=$(awk '/MemAvailable/ { print $2 }' /proc/meminfo)
    # Round down to nearest multiple of 50 MiB for improved test build caching
    ((memAvailableMiB = memAvailableKiB / (1024 * 50) * 50))
    ((memAvailableMiB < memoryMiB)) && memoryMiB=$memAvailableMiB
    >&2 echo "VM stats: CPUs: $numCPUs, memory: $memoryMiB MiB"
    >&2 echo "Host memory total: $((memTotalKiB / 1024)) MiB, available: $memAvailableMiB MiB"
    vmTestNixExpr
}

vmTestNixExpr() {
  cat <<EOF
    ((import "$scriptDir/tests.nix" { scenario = "$scenario"; }).vm {}).overrideAttrs (old: rec {
      buildCommand = ''
        export QEMU_OPTS="-smp $numCPUs -m $memoryMiB"
        echo "VM stats: CPUs: $numCPUs, memory: $memoryMiB MiB"
      '' + old.buildCommand;
    })
EOF
}

build() {
    if [[ $scenario ]]; then
        buildTest "$@"
    else
        scenario=default buildTest "$@"
        scenario=netns buildTest "$@"
    fi
}

# Set default scenario for all actions other than 'build'
if [[ $1 && $1 != build ]]; then
    : ${scenario:=default}
fi

eval "${@:-build}"
