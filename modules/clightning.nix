{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.clightning;
  home = "/var/lib/clightning";
  configFile = pkgs.writeText "config" ''
    autolisten=false
    network=bitcoin
    bitcoin-rpcuser=${cfg.bitcoin-rpcuser}
  '';
in {
  options.services.clightning = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the clightning service will be installed.
      '';
    };
    autolisten = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the clightning service will listen.
      '';
    };
    bitcoin-rpcuser = mkOption {
      type = types.string;
      description = ''
        Bitcoin RPC user
      '';
    };
  };

  config = mkIf cfg.enable {
      users.users.clightning =
        {
          description = "clightning User";
          createHome  = true;
          extraGroups = [ "bitcoinrpc" "keys" ];
          inherit home;
      };
      systemd.services.clightning =
        { description = "Run clightningd";
          path  = [ pkgs.bash pkgs.clightning pkgs.bitcoin ];
          wantedBy = [ "multi-user.target" ];
          requires = [ "bitcoind.service" ];
          after = [ "bitcoind.service" ];
          preStart = ''
            mkdir -p ${home}/.lightning
            rm -f ${home}/.lightning/config
            cp ${configFile} ${home}/.lightning/config
            chmod +w ${home}/.lightning/config
            echo "bitcoin-rpcpassword=$(cat /secrets/bitcoin-rpcpassword)" >> '${home}/.lightning/config'
            '';
          serviceConfig =
            {
              ExecStart = "${pkgs.clightning}/bin/lightningd";
              User = "clightning";
              Restart = "on-failure";
              RestartSec = "10s";
              PrivateTmp = "true";
              ProtectSystem = "full";
              NoNewPrivileges = "true";
              PrivateDevices = "true";
              MemoryDenyWriteExecute = "true";
            };
        };
    };
}
