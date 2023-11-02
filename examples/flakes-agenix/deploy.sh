#!/usr/bin/env bash
set -euo pipefail

# Strategy:
# 1. Copy the node flake (./flake.nix) to a temporary dir and create a Git repo.
# 2. Generate age-encrypted secrets by running a package defined by the node flake.
#    Commit the secrets.
# 3. Start the node in a container and run test commands.
#    The container is destroyed afterwards.
#
#    Run this script with arg `-i` or `--interactive` to start an
#    interactive shell in the container.

# You can use ./flake.nix as a template for a real deployment.

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 0. Prelude
interactive=
case "${1:-}" in
    -i|--interactive)
        interactive=1
        ;;
esac

cd "${BASH_SOURCE[0]%/*}"
scriptDir=$PWD
nixBitcoin="$scriptDir/../.."

tmpDir=$(mktemp -d /tmp/nix-bitcoin-agenix.XXX)
trap 'rm -rf $tmpDir' EXIT

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 1. Create a flake repo in a tmp dir
rsync -a ./ --exclude deploy.sh ./ "$tmpDir"

cd "$tmpDir"

git init
git add .
git commit -a -m init

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 2. Generate age-encrypted secrets

# Use this nix-bitcoin repo as the flake input when generating secrets,
# so that this script can be used for automated testing.
nix run --override-input nix-bitcoin "$nixBitcoin" .#generateAgeSecrets
#
# In a real deployment, you can simply run the following from the deployment repo root:
# nix run .#generateAgeSecrets
#
# or, if you don't define the `generateAgeSecrets` helper package:
# nix run .#nixosConfigurations.demo-node.config.nix-bitcoin.age.generateSecretsScript
#
# Show help
# nix run .#generateAgeSecrets --help

echo
echo "Encrypted secrets:"
ls -al secrets
echo

# Commit age-encrypted secrets
git add ./secrets
git commit -a -m 'add secrets'

# Success!
# This node flake can now be deployed with any deployment method.

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 3. Run node in container

if [[ $interactive ]]; then
    # Start interactive container shell
    runCmd=()
else
    runCmd=(
        --run c bash -c '
          echo
          echo "Unencrypted secrets in /run/agenix:"
          ls -alH /run/agenix
          echo
          systemctl status bitcoind
        '
    )
fi

runContainer=(
    nix run --override-input nix-bitcoin "$nixBitcoin" .#container -- "${runCmd[@]}"
)
nix shell --inputs-from "$nixBitcoin" extra-container -c "${runContainer[@]}"

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Debug helper: Build flake outputs
# nix build --no-link -L --print-out-paths --override-input nix-bitcoin "$nixBitcoin" .#container
# nix build --no-link -L --print-out-paths --override-input nix-bitcoin "$nixBitcoin" .#generateAgeSecrets
