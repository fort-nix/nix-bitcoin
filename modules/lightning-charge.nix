{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-charge;
  inherit (config) nix-bitcoin-services;
  user = config.users.users.lightning-charge.name;
  group = config.users.users.lightning-charge.group;
in {
  options.services.lightning-charge = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the lightning-charge service will be installed.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lightning-charge";
      description = "The data directory for lightning-charge.";
    };
  };

  config = mkIf cfg.enable {
    users.users.lightning-charge = {
      description = "lightning-charge User";
      group = "lightning-charge";
      extraGroups = [ "clightning" ];
    };
    users.groups.lightning-charge = {};

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 ${user} ${group} - -"
    ];

    environment.systemPackages = [ pkgs.nix-bitcoin.lightning-charge ];
    systemd.services.lightning-charge = {
      description = "Run lightning-charge";
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      preStart = ''
        # Move existing lightning-charge.db
        # TODO: Remove eventually
        if [[ -e ${config.services.clightning.dataDir}/lightning-charge.db ]]; then
          mv ${config.services.clightning.dataDir}/lightning-charge.db ${cfg.dataDir}/lightning-charge.db
          chown ${user}: ${cfg.dataDir}/lightning-charge.db
          chmod 600 ${cfg.dataDir}/lightning-charge.db
        fi
        '';
      serviceConfig = {
          PermissionsStartOnly = "true";
          EnvironmentFile = "${config.nix-bitcoin.secretsDir}/lightning-charge-env";
          ExecStart = "${pkgs.nix-bitcoin.lightning-charge}/bin/charged -l ${config.services.clightning.dataDir}/bitcoin -d ${cfg.dataDir}/lightning-charge.db";
          User = user;
          Restart = "on-failure";
          RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening
        // nix-bitcoin-services.nodejs
        // nix-bitcoin-services.allowTor;
    };
    nix-bitcoin.secrets.lightning-charge-env.user = user;
  };
}
