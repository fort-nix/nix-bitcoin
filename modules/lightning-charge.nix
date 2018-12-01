{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-charge;
in {
  options.services.lightning-charge = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the lightning-charge service will be installed.
      '';
    };
    clightning-datadir = mkOption {
      type = types.string;
      default = "/var/lib/clighting/";
      description = ''
        Data directory of the clightning service
      '';
    };
  };

  config = mkIf cfg.enable {
      users.users.lightning-charge =
        {
          description = "lightning-charge User";
          group = "lightning-charge";
          extraGroups = [ "keys" ];
      };
      users.groups.lightning-charge = {
        name = "lightning-charge";
      };

      systemd.services.lightning-charge =
        { description = "Run lightning-charge";
          wantedBy = [ "multi-user.target" ];
          requires = [ "clightning.service" ];
          after = [ "clightning.service" ];
          serviceConfig =
            {
              EnvironmentFile = "/secrets/lightning-charge-api-token";
              ExecStart = "${pkgs.lightning-charge.package}/bin/charged -l ${config.services.clightning.dataDir} -d ${config.services.clightning.dataDir}/lightning-charge.db";

              User = "clightning";
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
