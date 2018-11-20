{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.onionnode;
in {
  options.services.onionnode = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the onion service will be installed.
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
  };
}
