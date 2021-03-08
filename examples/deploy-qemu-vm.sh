#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to run a nix-bitcoin node in QEMU.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Run with option `--interactive` or `-i` to start a shell for interacting with
# the node.

# MAKE SURE TO REPLACE the SSH identity file if you use this script for
# anything serious.

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "./${BASH_SOURCE[0]##*/} $*"
fi

source qemu-vm/run-vm.sh

echo "Building VM"
nix-build --out-link $tmpDir/vm - <<'EOF'
(import <nixpkgs/nixos> {
  configuration = {
    imports = [
      <configuration.nix>
      <qemu-vm/vm-config.nix>
      <nix-bitcoin/modules/secrets/generate-secrets.nix>
    ];
  };
}).vm
EOF

vmNumCPUs=4
vmMemoryMiB=2048
sshPort=60734
runVM $tmpDir/vm $vmNumCPUs $vmMemoryMiB $sshPort

vmWaitForSSH
echo "Waiting until services are ready..."
c '
attempts=300
while ! systemctl is-active clightning &> /dev/null; do
    ((attempts-- == 0)) && { echo "timeout"; exit 1; }
    sleep 0.2
done
'
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

case ${1:-} in
    -i|--interactive)
        . start-bash-session.sh
        ;;
esac

# Cleanup happens at exit (defined in qemu-vm/run-vm.sh)
