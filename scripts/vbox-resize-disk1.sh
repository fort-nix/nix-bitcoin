set -ex

DEPLOYMENT="bitcoin-node"
MACHINE="bitcoin-node"
DISK_FILE=$(nixops export -d $DEPLOYMENT | nix-shell -p jq --command "jq -r '..|.\"virtualbox.disks\"?|select(.!=null)' | jq -r .disk1.path")

nixops stop -d $DEPLOYMENT
VBoxManage modifyhd --resize 307200 "$DISK_FILE"
nixops start -d $DEPLOYMENT

# (
# echo d # [d]elete 50gb partition
# echo n # [n]ew partitoin
# echo p # [p]rimary partition
# echo   # partition number (Accept default: 1)
# echo   # first sector (Accept default: 1)
# echo   # last sector (Accept default: 524287999)
# echo w # [w]rite changes
# ) | fdisk
nixops ssh -d $DEPLOYMENT $MACHINE -- '(echo d; echo n; echo p; echo; echo; echo; echo w; ) | fdisk /dev/sda'

nixops reboot -d $DEPLOYMENT
nixops ssh -d $DEPLOYMENT $MACHINE -- resize2fs /dev/sda1
nixops ssh -d $DEPLOYMENT $MACHINE -- df -h
