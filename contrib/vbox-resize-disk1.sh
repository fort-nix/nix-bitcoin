#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq

while getopts ":d:m:s:f:yh" opt; do
  case $opt in
    d)
      DEPLOYMENT="$OPTARG"
      ;;
    m)
      MACHINE="$OPTARG"
      ;;
    s)
      NEW_SIZE="$OPTARG"
      ;;
    f)
      DISK_FILE="$OPTARG"
      ;;
    y)
      YES="yes"
      ;;
    h)
      echo "Usage: $0 [-d <deployment>] [-m <machine>] [-s <size>] [-f <file>] [-y]"
      echo ""
      echo "Options:"
      echo "  -d <deployment>  NixOps deployment name. Default: bitcoin-node."
      echo "  -m <machine>     NixOps machine name. Default: bitcoin-node."
      echo "  -s <size>        New disk size in megabytes. Default: 307200 (300gb)."
      echo "  -f <file>        Path to vbox disk file/VDI. Default: read from nixops export."
      echo "  -y               Don't ask for confirmation."
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

DEPLOYMENT=${DEPLOYMENT:-"bitcoin-node"}
MACHINE=${MACHINE:-"bitcoin-node"}
NEW_SIZE=${NEW_SIZE:-307200}
DISK_FILE=${DISK_FILE:-$(nixops export -d $DEPLOYMENT | jq -r '..|."virtualbox.disks"?|select(.!=null)' | jq -r .disk1.path)}

echo "Resizing virtualbox disk for use with nixops and nix-bitcoin."
echo "Using deployment: $DEPLOYMENT"
echo "Using machine: $MACHINE"
echo "Using size: $NEW_SIZE"
echo "Using disk file: $DISK_FILE"

if [ "$YES" != "yes" ]; then
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

set -ex

nixops stop -d $DEPLOYMENT
VBoxManage modifyhd --resize $NEW_SIZE "$DISK_FILE"
nixops start -d $DEPLOYMENT

# (
# echo d # [d]elete 50gb partition
# echo n # [n]ew partitoin
# echo p # [p]rimary partition
# echo   # partition number (Accept default: 1)
# echo   # first sector (Accept default: 1)
# echo   # last sector (Accept default: determined by $NEW_SIZE)
# echo w # [w]rite changes
# ) | fdisk
nixops ssh -d $DEPLOYMENT $MACHINE -- '(echo d; echo n; echo p; echo; echo; echo; echo w; ) | fdisk /dev/sda'

nixops reboot -d $DEPLOYMENT
nixops ssh -d $DEPLOYMENT $MACHINE -- resize2fs /dev/sda1
nixops ssh -d $DEPLOYMENT $MACHINE -- df -h
