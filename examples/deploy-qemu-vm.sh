#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to run a nix-bitcoin node in QEMU.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Feel free to modify or to run nix-shell and execute individual statements of this
# script in the interactive shell.

# MAKE SURE TO REPLACE the SSH identity file if you use this script for
# anything serious.

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "${BASH_SOURCE[0]}"
fi

tmpDir=/tmp/nix-bitcoin-qemu-vm
mkdir -p $tmpDir

# Cleanup on exit
cleanup() {
    set +eu
    kill -9 $qemuPID
    rm -rf $tmpDir
}
trap "cleanup" EXIT

identityFile=qemu-vm/id-vm
chmod 0600 $identityFile

echo "Building VM"
nix-build --out-link $tmpDir/vm - <<EOF
(import <nixpkgs/nixos> {
  configuration = {
    imports = [
      <nix-bitcoin/examples/configuration.nix>
      <nix-bitcoin/modules/secrets/generate-secrets.nix>
    ];
    virtualisation.graphics = false;
    services.mingetty.autologinUser = "root";
    users.users.root = {
      openssh.authorizedKeys.keys = [ "$(cat $identityFile.pub)" ];
    };
  };
}).vm
EOF

vmMemoryMiB=2048
vmNumCPUs=4
sshPort=60734

export NIX_DISK_IMAGE=$tmpDir/img
export QEMU_NET_OPTS=hostfwd=tcp::$sshPort-:22
</dev/null $tmpDir/vm/bin/run-*-vm -m $vmMemoryMiB -smp $vmNumCPUs &>/dev/null &
qemuPID=$!

# Run command in VM
c() {
    ssh -p $sshPort -i $identityFile -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-connection -o ControlPersist=60 \
        root@127.0.0.1 "$@"
}

echo
echo "Waiting for SSH connection..."
while ! c : 2>/dev/null; do :; done

echo
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

# Uncomment to start a shell session here
# . start-bash-session.sh

# Cleanup happens at exit (see above)
