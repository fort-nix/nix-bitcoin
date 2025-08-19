#!/usr/bin/env bash

# Modules integration test runner.
# The tests (defined in ./tests.nix) use the NixOS testing framework and are executed in a VM.
#
# Usage:
#   Run the basic set of tests. These are also run on the CI server.
#   ./run-tests.sh
#
#   Test specific scenario
#   ./run-tests.sh --scenario|-s <scenario>
#
#   - When <scenario> contains a space, <scenario> is treated as nix code defining
#     a scenario. It is evaluated in the same context as other scenarios in ./tests.nix
#
#     Example:
#     ./run-tests.sh -s "{ nix-bitcoin.nodeinfo.enable = true; }" container --run c nodeinfo
#
#   - When <scenario> does not name a scenario, the test is run with an adhoc scenario
#     where services.<scenario> is enabled.
#
#     Example:
#     ./run-tests.sh -s electrs
#
#   Run test(s) and link results to avoid garbage collection
#   ./run-tests.sh [--scenario <scenario>] --out-link-prefix /tmp/nix-bitcoin-test
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
#   Run a test scenario in a container
#   sudo ./run-tests.sh [--scenario <scenario>] container
#
#     This is useful for quick experiments; containers start much faster than VMs.
#     Running the Python test suite in containers is not yet supported.
#     For now, creating NixOS containers requires root permissions.
#     See ./lib/make-container.sh for a complete documentation.
#
#   Run a test scenario in a regular NixOS VM.
#   No tests are executed, the machine's serial console is attached to your terminal.
#   ./run-tests.sh [--scenario <scenario>] vm
#
#     This is useful for directly exploring a test configuration without the
#     intermediate Python REPL layer.
#     Run command 'q' inside the machine for instant poweroff.
#
#   Run tests from a snapshot copy of the source files
#   ./run-tests.sh --copy-src|-c ...
#
#     This allows you to continue editing the nix-bitcoin sources while tests are running
#     and reading source files.
#     Files are copied to /tmp, a caching scheme helps minimizing copies.
#
#   Add custom scenarios from a file
#   ./run-tests.sh --extra-scenarios ~/my/scenarios.nix ...

set -eo pipefail

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

args=("$@")
scenario=
outLinkPrefix=
scenarioOverridesFile=
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
        --extra-scenarios)
            if [[ $2 ]]; then
                scenarioOverridesFile=$2
                shift
                shift
            else
                >&2 echo "Error: $1 requires an argument."
                exit 1
            fi
            ;;
        --copy-src|-c)
            shift
            if [[ ! $_nixBitcoinInCopiedSrc ]]; then
                . "$scriptDir/lib/copy-src.sh"
                exit
            fi
            ;;
        *)
            break
    esac
done

tmpDir=
# Sets global var `tmpDir`
makeTmpDir() {
    if [[ ! $tmpDir ]]; then
        tmpDir=$(mktemp -d /tmp/nix-bitcoin-tests.XXX)
        # shellcheck disable=SC2064
        trap "rm -rf '$tmpDir'" EXIT
    fi
}

# Support explicit scenario definitions
if [[ $scenario = *' '* ]]; then
    makeTmpDir
    scenarioOverridesFile=$tmpDir/scenario-overrides.nix
    echo "{ scenarios, pkgs, lib, nix-bitcoin }: with lib; { tmp = $scenario; }" > "$scenarioOverridesFile"
    scenario=tmp
fi

# Run the test. No temporary files are left on the host system.
run() {
    makeTmpDir
    buildTestAttr .run --out-link "$tmpDir/run-vm"
    NIX_BITCOIN_VM_DATADIR=$tmpDir "$tmpDir/run-vm/bin/run-vm" "$@"
}

debug() {
    run --debug
}

container() {
    local nixosContainer
    if ! nixosContainer=$(type -p nixos-container) \
       || grep -q '"/etc/nixos-containers"' "$nixosContainer"; then
        local attr=container
    else
        # NixOS with `system.stateVersion` <22.05
        local attr=containerLegacy
    fi
    echo "Building container"
    makeTmpDir
    export container=$tmpDir/container
    buildTestAttr ".$attr" --out-link "$container"
    export scriptDir
    "$scriptDir/lib/make-container.sh" "$@"
}

# Run a regular NixOS VM
vm() {
    makeTmpDir
    buildTestAttr .vm --out-link "$tmpDir/vm"
    NIX_BITCOIN_VM_DATADIR=$tmpDir "$tmpDir/vm/bin/run-vm-in-tmpdir"
}

# Run the test by building the test derivation
buildTest() {
    buildTestAttr "" "$@"
}

evalTest() {
    nixInstantiateTest "" "$@"
    # Print out path
    nix-store -q "$drv"
    # Print drv path
    realpath "$drv"
}

buildTestAttr() {
    local attr=$1
    shift
    # TODO-EXTERNAL:
    # Simplify and switch to pure build when `nix build` can build flake function outputs
    nixInstantiateTest "$attr"
    nixBuild "$scenario" "$drv" "$@"
}

buildTests() {
    local -n tests=$1
    shift
    makeTmpDir
    # TODO-EXTERNAL:
    # Simplify and switch to pure build when `nix build` can instantiate flake function outputs
    # shellcheck disable=SC2207
    drvs=($(nixInstantiate "pkgs.instantiateTestsFromStr \"${tests[*]}\""))
    for i in "${!tests[@]}"; do
        testName=${tests[$i]}
        drv=${drvs[$i]}
        echo
        echo "Building test '$testName'"
        nixBuild "$testName" "$drv" "$@"
    done
}

# Instantiate an attr of the test defined in global var `scenario`
nixInstantiateTest() {
    local attr=$1
    shift
    if [[ $scenarioOverridesFile ]]; then
        local file="extraScenariosFile = \"$scenarioOverridesFile\";"
    else
        local file=
    fi
    nixInstantiate "(pkgs.getTest { name = \"$scenario\"; $file })$attr" "$@" >/dev/null
}

drv=
# Sets global var `drv` to the gcroot link of the instantiated derivation
nixInstantiate() {
    local expr=$1
    shift
    makeTmpDir
    drv="$tmpDir/drv"
    nix-instantiate --add-root "$drv" -E "
      let
        pkgs = (builtins.getFlake \"git+file://$scriptDir/..\").legacyPackages.\${builtins.currentSystem};
      in
        $expr
    " "$@"
}

nixBuild() {
    local outLinkName=$1
    local drv=$2
    shift
    shift
    args=(--print-out-paths -L)
    if [[ $outLinkPrefix ]]; then
        args+=(--out-link "$outLinkPrefix-$outLinkName")
    else
        args+=(--no-link)
    fi
    if isNixVersionGreaterEqual_2_15; then
        # This syntax is supported by Nix ≥ 2.13
        drv="$(realpath "$drv")^*"
    fi
    nix build "$drv" "${args[@]}" "$@"
}

isNixGE_2_15=undefined
isNixVersionGreaterEqual_2_15() {
    if [[ $isNixGE_2_15 == undefined ]]; then
        isNixGE_2_15=
        if {
            echo '2.15'
            nix --version | awk '{print $NF}'
        } | sort -C -V; then
            isNixGE_2_15=1
        fi
    fi
    [[ $isNixGE_2_15 ]]
}

flake() {
    nix flake check --all-systems "$scriptDir/.."
}

# Test generating module documentation for search.nixos.org
nixosSearch() {
    if [[ $outLinkPrefix ]]; then
        # Add gcroots for flake-info
        nix build "$scriptDir/nixos-search#flake-info" -o "$outLinkPrefix-flake-info"
    fi
    "$scriptDir/nixos-search/flake-info-sandboxed.sh"
}

persistentContainerExample() {
    . "$scriptDir/lib/extra-container-check-version.sh"
    nix run "$scriptDir/../examples/container" --override-input nix-bitcoin "$scriptDir/.." -- --run c systemctl status electrs
}

# A basic subset of tests to keep the total runtime within
# manageable bounds.
# These are also run on the CI server.
basic=(
    default
    netns
    netnsRegtest
)
basic() { buildTests basic "$@"; }

# All tests that only consist of building a nix derivation.
# shellcheck disable=2034
buildable=(
    "${basic[@]}"
    full
    regtest
    hardened
    clightning-replication
    lndPruned
    wireguard-lndconnect
    trustedcoin
)
buildable() { buildTests buildable "$@"; }

examples() {
    # shellcheck disable=SC2016
    script='
      set -e
      runExample() { echo; echo Running example $1; ./$1; }
      runExample deploy-container.sh
      runExample deploy-container-minimal.sh
      runExample deploy-qemu-vm.sh
      runExample deploy-krops.sh
    '
    (cd "$scriptDir/../examples" && nix-shell --run "$script")

    echo
    echo "Running example 'Persistent container'"
    persistentContainerExample
}

shellcheck() {
    "$scriptDir/shellcheck.sh"
}

all() {
    buildable "$@"
    shellcheck
    examples
    flake
    nixosSearch
}

# An alias for buildTest
build() {
    buildTest "$@"
}

if [[ $# -gt 0 && $1 != -* ]]; then
    # An explicit command was provided
    command=$1
    shift
    if [[ $command == eval ]]; then
        command=evalTest
    fi
    : "${scenario:=default}"
elif [[ $scenario ]]; then
    command=buildTest
else
    command=basic
fi
$command "$@"
