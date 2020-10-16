#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to setup a nix-bitcoin node in a NixOS container.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Feel free to modify or to run nix-shell and execute individual statements of this
# script in the interactive shell.

if [[ $(sysctl -n net.ipv4.ip_forward) != 1 ]]; then
    echo "Error: IP forwarding (net.ipv4.ip_forward) is not enabled."
    echo "Needed for container WAN access."
    exit 1
fi

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "${BASH_SOURCE[0]}"
fi

# Uncomment to start a container shell session
# interactive=1

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
echo "Node info:"
c nodeinfo
echo
echo "Bitcoind data dir:"
sudo ls -al /var/lib/containers/demo-node/var/lib/bitcoind
'

if [[ ${interactive:-} ]]; then
    runCmd=
else
    runCmd=(--run bash -c "$demoCmds")
fi

# Build container.
# Learn more: https://github.com/erikarvstedt/extra-container
#
read -d '' src <<'EOF' || true
{ pkgs, lib, ... }: {
  containers.demo-node = {
    extra.addressPrefix = "10.250.0";
    extra.enableWAN = true;
    config = { pkgs, config, lib, ... }: {
      imports = [
        <nix-bitcoin/examples/configuration.nix>
        <nix-bitcoin/modules/secrets/generate-secrets.nix>
      ];
    };
  };
}
EOF
$([[ $EUID = 0 ]] || echo sudo "PATH=$PATH" "NIX_PATH=$NIX_PATH") \
    $(type -P extra-container) shell -E "$src" "${runCmd[@]}"

# The container is automatically deleted at exit
