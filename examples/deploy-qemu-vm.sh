#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to run a nix-bitcoin node in QEMU.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Run with option `--interactive` or `-i` to start a shell for interacting with
# the node.

# MAKE SURE TO REPLACE the SSH identity file if you use this script for
# anything serious.

if [[ ! -v NIX_BITCOIN_EXAMPLES_DIR ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "./${BASH_SOURCE[0]##*/} $*"
else
    cd "$NIX_BITCOIN_EXAMPLES_DIR"
fi

source qemu-vm/run-vm.sh

echo "Building VM"
nix-build --out-link "$tmpDir/vm" - <<'EOF'
(import <nixpkgs/nixos> {
  configuration = {
    imports = [
      <configuration.nix>
      <qemu-vm/vm-config.nix>
    ];
    nix-bitcoin.generateSecrets = true;
  };
}).config.system.build.vm
EOF

vmNumCPUs=4
vmMemoryMiB=2048
sshPort=60734
runVM "$tmpDir/vm" "$vmNumCPUs" "$vmMemoryMiB" "$sshPort"

vmWaitForSSH
printf "Waiting until services are ready"
c "
$(cat qemu-vm/wait-until.sh)
waitUntil 'systemctl is-active clightning &> /dev/null' 100
"
echo

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
        . ./start-bash-session.sh
        ;;
esac

# Cleanup happens at exit (defined in qemu-vm/run-vm.sh)
