{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.bitcoin;
  home = "/var/lib/bitcoin";
  configFile = pkgs.writeText "bitcoin.conf" ''
      listen=0
      onlynet=onion
      prune=1001
      assumevalid=0000000000000000000726d186d6298b5054b9a5c49639752294b322a305d240
      proxy=127.0.0.1:9050
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
