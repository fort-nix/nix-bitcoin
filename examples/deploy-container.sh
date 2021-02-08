#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to setup a nix-bitcoin node in a NixOS container.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Run with option `--interactive` or `-i` to start a shell for interacting with
# the node.

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "./${BASH_SOURCE[0]##*/} $*"
fi

if [[ $(sysctl -n net.ipv4.ip_forward || sudo sysctl -n net.ipv4.ip_forward) != 1 ]]; then
    echo "Error: IP forwarding (net.ipv4.ip_forward) is not enabled."
    echo "Needed for container WAN access."
    exit 1
fi

if [[ $EUID != 0 ]]; then
    # NixOS containers require root permissions
    exec sudo "PATH=$PATH" "NIX_PATH=$NIX_PATH" "IN_NIX_SHELL=$IN_NIX_SHELL" "${BASH_SOURCE[0]}" "$@"
fi

interactive=
minimalConfig=
for arg in "$@"; do
    case $arg in
        -i|--interactive)
            interactive=1
            ;;
        --minimal-config)
            minimalConfig=1
            ;;
    esac
done

# These commands can also be executed interactively in a shell session
demoCmds='
echo
echo "Bitcoind service:"
c systemctl status bitcoind
echo
echo "Bitcoind network:"
c bitcoin-cli getnetworkinfo
echo
echo "lightning-cli state:"
c lightning-cli getinfo
echo
echo "Bitcoind data dir:"
sudo ls -al /var/lib/containers/demo-node/var/lib/bitcoind
'
nodeInfoCmd='
echo
echo "Node info:"
c nodeinfo
'

if [[ $minimalConfig ]]; then
    configuration=minimal-configuration.nix
else
    configuration=configuration.nix
    demoCmds="${demoCmds}${nodeInfoCmd}"
fi

if [[ $interactive ]]; then
    runCmd=()
else
    runCmd=(--run bash -c "$demoCmds")
fi

# Build container.
# Learn more: https://github.com/erikarvstedt/extra-container
#
read -d '' src <<EOF || true
{ pkgs, lib, ... }: {
  containers.demo-node = {
    extra.addressPrefix = "10.250.0";
    extra.enableWAN = true;
    config = { pkgs, config, lib, ... }: {
      imports = [
        <nix-bitcoin/examples/${configuration}>
        <nix-bitcoin/modules/secrets/generate-secrets.nix>
      ];
    };
  };
}
EOF
extra-container shell -E "$src" "${runCmd[@]}"

# The container is automatically deleted at exit
