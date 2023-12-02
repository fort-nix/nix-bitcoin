{ lib, ... }: {
  imports = [
    ./configuration.nix
    <nix-bitcoin/modules/deployment/krops.nix>
    <qemu-vm/vm-config.nix>
  ];
}
