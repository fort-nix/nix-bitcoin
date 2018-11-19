{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.bitcoin;
  home = "/var/lib/bitcoin";
  configFile = pkgs.writeText "bitcoin.conf" ''
      listen=${if cfg.listen then "1" else "0"}
      prune=1001
      assumevalid=0000000000000000000726d186d6298b5054b9a5c49639752294b322a305d240
      ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}
      addnode=ecoc5q34tmbq54wl.onion
      discover=0
      ${optionalString (cfg.port != null) "port=${toString cfg.port}"}
      '';
in {
  options.services.bitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the bitcoin service will be installed.
      '';
    };
    listen = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the bitcoin service will listen.
      '';
    };
    proxy = mkOption {
      type = types.nullOr types.string;
      default = null;
      description = ''
        proxy
      '';
    };
    port = mkOption {
        type = types.nullOr types.ints.u16;
        default = null;
#        type = types.int;
        #default = 8333;
        description = "Override the default port on which to listen for connections.";
    };

  };

  config = mkIf cfg.enable {
      users.users.bitcoin =
        {
          description = "Bitcoind User";
          createHome  = true;
          inherit home;
      };
      systemd.services.bitcoind =
        { description = "Run bitcoind";
          path  = [ pkgs.bitcoin ];
          wantedBy = [ "multi-user.target" ];
          preStart = ''
            mkdir -p ${home}/.bitcoin
            ln -sf ${configFile} ${home}/.bitcoin/bitcoin.conf
            '';
          serviceConfig =
            {
              ExecStart = "${pkgs.bitcoin}/bin/bitcoind";
              User = "bitcoin";
            };
        };
    };
}
