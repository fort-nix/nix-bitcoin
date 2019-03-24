{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.electrs;
  index-batch-size = "${if cfg.high-memory then "" else "--index-batch-size=10"}";
  jsonrpc-import = "${if cfg.high-memory then "" else "--jsonrpc-import"}";
in {
  options.services.electrs = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the electrs service will be installed.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/electrs";
      description = "The data directory for electrs.";
    };
    high-memory = mkOption {
      type = types.bool;
      default = false;
      description = ''
      If enabled, the electrs service will sync faster on high-memory systems (≤ 8GB).
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.electrs = {
        description = "electrs User";
        group = "electrs";
        extraGroups = [ "bitcoinrpc" "keys" "bitcoin"];
        home = cfg.dataDir;
    };
    users.groups.electrs = {
      name = "electrs";
    };   

    systemd.services.electrs = {
      description = "Run electrs";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      # create shell script to start up electrs safely with password parameter
      preStart = ''
        mkdir -m 0770 -p ${cfg.dataDir}
        chown 'electrs:electrs' ${cfg.dataDir}
        echo "${pkgs.electrs}/bin/electrs -vvv ${index-batch-size} ${jsonrpc-import} --timestamp --db-dir ${cfg.dataDir} --daemon-dir /var/lib/bitcoind --cookie=${config.services.bitcoind.rpcuser}:$(cat /secrets/bitcoin-rpcpassword)" > /var/lib/electrs/startscript.sh
        chown -R 'electrs:electrs' ${cfg.dataDir}
        chmod u+x ${cfg.dataDir}/startscript.sh
        '';	
      serviceConfig = {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.dataDir}/startscript.sh";
        User = "electrs";
        Restart = "on-failure";
        RestartSec = "10s";
        PrivateTmp = "true";
        ProtectSystem = "full";
        NoNewPrivileges = "true";
        PrivateDevices = "true";
      };
    };
  };
}
