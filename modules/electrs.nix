{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.electrs;
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
  };

  config = mkIf cfg.enable {
    users.users.electrs = {
        description = "electrs User";
        group = "electrs";
        extraGroups = [ "bitcoinrpc" "keys" ];
        home = cfg.dataDir;
    };
    users.groups.electrs = {
      name = "electrs";
    };   

    systemd.services.electrs = {
      description = "Run electrs";
      wantedBy = [ "muli-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      # create shell script to start up electrs safely with password parameter
      preStart = ''
        mkdir -m 0770 -p ${cfg.dataDir}
	chown 'electrs:electrs' ${cfg.dataDir}
	echo "${pkgs.electrs}/bin/electrs -vvv --timestamp --db-dir ${cfg.dataDir} --daemon-dir /var/lib/bitcoind --cookie=${config.services.bitcoind.rpcuser}:$(cat /secrets/bitcoin-rpcpassword)" > /var/lib/electrs/startscript.sh
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
