{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.clightning;
  configFile = pkgs.writeText "config" ''
    autolisten=${toString cfg.autolisten}
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
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/clightning";
      description = "The data directory for bitcoind.";
    };
  };

  config = mkIf cfg.enable {
      users.users.clightning =
        {
          description = "clightning User";
          group = "clightning";
          extraGroups = [ "bitcoinrpc" "keys" ];
          home = cfg.dataDir;
      };
      users.groups.clightning = {
        name = "clightning";
      };

      systemd.services.clightning =
        { description = "Run clightningd";
          path  = [ pkgs.bash pkgs.clightning pkgs.bitcoin ];
          wantedBy = [ "multi-user.target" ];
          requires = [ "bitcoind.service" ];
          after = [ "bitcoind.service" ];
          preStart = ''
            mkdir -m 0770 -p ${cfg.dataDir}
            rm -f ${cfg.dataDir}/config
            chown 'clightning:clightning' '${cfg.dataDir}'
            cp ${configFile} ${cfg.dataDir}/config
            chown 'clightning:clightning' '${cfg.dataDir}/config'
            chmod +w ${cfg.dataDir}/config
            chmod o-rw ${cfg.dataDir}/config
            echo "bitcoin-rpcpassword=$(cat /secrets/bitcoin-rpcpassword)" >> '${cfg.dataDir}/config'
            '';
          serviceConfig =
            {
              PermissionsStartOnly = "true";
              ExecStart = "${pkgs.clightning}/bin/lightningd --lightning-dir=${cfg.dataDir}";
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
