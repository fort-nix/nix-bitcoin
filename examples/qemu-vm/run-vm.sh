qemuDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

# shellcheck disable=SC1091
source "$qemuDir/wait-until.sh"

tmpDir=/tmp/nix-bitcoin-qemu-vm
mkdir -p "$tmpDir"

# Cleanup on exit
cleanup() {
    set +eu
    if [[ $qemuPID ]]; then
        kill -9 "$qemuPID"
    fi
    rm -rf "$tmpDir"
}
trap "cleanup" EXIT

identityFile=$qemuDir/id-vm
chmod 0600 "$identityFile"

runVM() {
    vm=$1
    vmNumCPUs=$2
    vmMemoryMiB=$3
    sshPort=$4

    export NIX_DISK_IMAGE="$tmpDir/img"
    export QEMU_NET_OPTS="hostfwd=tcp::${sshPort}-:22"
    # shellcheck disable=SC2211
    </dev/null "$vm"/bin/run-*-vm -m "$vmMemoryMiB" -smp "$vmNumCPUs" &>/dev/null &
    qemuPID=$!
}

vmWaitForSSH() {
    echo
    printf "Waiting for SSH connection..."
    waitUntil "c : 2>/dev/null" 500
    echo
}

# Run command in VM
c() {
    ssh -p "$sshPort" -i "$identityFile" -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-connection -o ControlPersist=60 \
        root@127.0.0.1 "$@"
}
export identityFile
export sshPort
export tmpDir
export -f c
