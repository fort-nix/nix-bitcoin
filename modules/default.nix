{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.bitcoin;
  datadir = "/var/lib/bitcoin";
in {
  options.services.bitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the bitcoin service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.bitcoin =
      {
        description = "Tor Daemon User";
        createHome  = true;
        home        = datadir;
    };
    systemd.services.bitcoind =
      { description = "Run bitcoind";
        path  = [ pkgs.bitcoin ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
          { ExecStart = "${pkgs.bitcoin}/bin/bitcoind -datadir=${datadir}";
            User = "bitcoin";
          };
      };
  };
}
