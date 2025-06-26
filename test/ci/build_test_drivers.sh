#!/usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}"

cachixCache=nix-bitcoin

# Declare variables for shellcheck
driverDrvs=()
drivers=()
scenarioTests=()

# Call ./test-info.nix
testInfo=$(time nix eval --raw --show-trace ../..#ciTestInfo)
# This sets variables `driverDrvs`, `drivers`, `scenarioTests`
eval "$testInfo"

if nix path-info --store "https://${cachixCache}.cachix.org" "${scenarioTests[@]}" &>/dev/null; then
    echo
    echo "All tests have already been built successfully:"
    printf '%s\n' "${scenarioTests[@]}"
    exit 0
fi

echo "run_scenario_tests=true" >> "$GITHUB_OUTPUT"

## Build test drivers

if nix path-info --store "https://${cachixCache}.cachix.org" "${drivers[@]}" &>/dev/null; then
    echo
    echo "All test drivers have already been built successfully:"
    exit 0
fi

if [[ -v GITHUB_ACTIONS ]]; then
    # Avoid cachix warning message
    mkdir -p ~/.config/nix && touch ~/.config/nix/nix.conf
    cachix use "$cachixCache"
fi

if [[ $CACHIX_SIGNING_KEY ]]; then
    # Speed up task by uploading store paths as soon as they are created
    buildCmd="cachix watch-exec $cachixCache nix -- build"
else
    buildCmd="nix build"
fi

$buildCmd --no-link --print-build-logs "${driverDrvs[@]}"

if [[ $CACHIX_SIGNING_KEY ]]; then
    cachix push "$cachixCache" "${drivers[@]}"
fi
