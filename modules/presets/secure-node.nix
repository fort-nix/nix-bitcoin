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
    # For backwards compatibility only
    nix-bitcoin.secretsDir = mkDefault "/secrets";

    networking.firewall.enable = true;

    nix-bitcoin.security.dbusHideProcessInformation = true;

    # Use doas instead of sudo
    security.doas.enable = true;
    security.sudo.enable = false;

    environment.systemPackages = with pkgs; [
      jq
    ];

    # sshd
    services.tor.relay.onionServices.sshd = nbLib.mkOnionService { port = 22; };
    nix-bitcoin.onionAddresses.access.${operatorName} = [ "sshd" ];

    services.bitcoind = {
      enable = true;
      listen = true;
      dbCache = 1000;
    };

    services.liquidd = {
      prune = 1000;
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
