{ lib, ... }: {
  imports = [
    ./configuration.nix
    <nix-bitcoin/modules/deployment/krops.nix>
    <qemu-vm/vm-config.nix>
  ];

  # TODO-EXTERNAL:
  # When bitcoind is not fully synced, the offers plugin in clightning 24.05
  # crashes (see https://github.com/ElementsProject/lightning/issues/7378).
  services.clightning.extraConfig = ''
    disable-plugin=offers
  '';
}
