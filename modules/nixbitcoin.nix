{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin;
in {
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
    services.bitcoin.enable = true;
    services.bitcoin.listen = true;
    services.tor.enable = true;
    services.tor.client.enable = true;
    services.bitcoin.proxy = config.services.tor.client.socksListenAddress;
    services.bitcoin.port = 8333;
    services.tor.hiddenServices.bitcoind = {
      map = [{
        port = config.services.bitcoin.port;
      }];
      version = 3;
    };
    systemd.services.nodeinfo = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c ${pkgs.nodeinfo}/bin/nodeinfo";
        user = "root";
        type = "oneshot";
      };
    };
  };
}
