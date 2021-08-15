{ config, pkgs, lib, ... }: {
  imports = [
    <nix-bitcoin/modules/nix-bitcoin.nix>
  ];

  nix-bitcoin.generateSecrets = true;

  services.bitcoind.enable = true;
  services.clightning.enable = true;

  # When using nix-bitcoin as part of a larger NixOS configuration, set the following to enable
  # interactive access to nix-bitcoin features (like bitcoin-cli) for your system's main user
  nix-bitcoin.operator = {
    enable = true;
    name = "main"; # Set this to your system's main user
  };

  # The system's main unprivileged user. This setting is usually part of your
  # existing NixOS configuration.
  users.users.main = {
    isNormalUser = true;
    password = "a";
  };
}
