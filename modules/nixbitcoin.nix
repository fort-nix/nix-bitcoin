{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin;
in {
  imports =
    [
      ./bitcoind.nix
      ./tor.nix
      ./clightning.nix
    ];

  options.services.nixbitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nix-bitcoin service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Tor
    services.tor.enable = true;
    services.tor.client.enable = true;
    services.tor.hiddenServices.bitcoind = {
      map = [{
        port = config.services.bitcoin.port;
      }];
      version = 3;
    };

    # bitcoin
    services.bitcoin.enable = true;
    services.bitcoin.listen = true;
    services.bitcoin.proxy = config.services.tor.client.socksListenAddress;
    services.bitcoin.port = 8333;

    # clightning
    services.clightning.enable = true;

    # nodeinfo
    systemd.services.nodeinfo = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      path  = [ pkgs.clightning pkgs.jq pkgs.sudo ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c ${pkgs.nodeinfo}/bin/nodeinfo";
        user = "root";
        type = "oneshot";
      };
    };
  };
}
