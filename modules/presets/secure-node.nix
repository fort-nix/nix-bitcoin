{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;
  nbLib = config.nix-bitcoin.lib;
  operatorName = config.nix-bitcoin.operator.name;
in {
  imports = [
    ../modules.nix
    ./enable-tor.nix
  ];

  options = {
    # Used by ../versioning.nix
    nix-bitcoin.secure-node-preset-enabled = {};
  };

  config =  {
    networking.firewall.enable = true;

    nix-bitcoin.security.dbusHideProcessInformation = true;

    # Use doas instead of sudo
    security.doas.enable = true;
    security.sudo.enable = false;
    environment.shellAliases.sudo = "doas";

    environment.systemPackages = with pkgs; [
      jq
    ];

    # Add a SSH onion service
    services.tor.relay.onionServices.sshd = nbLib.mkOnionService { port = 22; };
    nix-bitcoin.onionAddresses.access.${operatorName} = [ "sshd" ];

    services.bitcoind = {
      enable = true;
      listen = true;
      dbCache = 1000;
    };

    services.liquidd = {
      # Enable `validatepegin` to verify that a transaction sending BTC into
      # Liquid exists on Bitcoin. Without it, a malicious liquid federation can
      # make the node accept a sidechain that is not fully backed.
      validatepegin = true;
      listen = true;
    };

    nix-bitcoin.nodeinfo.enable = true;

    services.backups.frequency = "daily";

    # operator
    nix-bitcoin.operator.enable = true;
    users.users.${operatorName} = {
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
    };
  };
}
