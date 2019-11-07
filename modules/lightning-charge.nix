{ config, lib, pkgs, ... }:

with lib;

let
  nix-bitcoin-services = pkgs.callPackage ./nix-bitcoin-services.nix { };
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
      type = types.str;
      default = "/var/lib/clighting/";
      description = ''
        Data directory of the clightning service
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.lightning-charge = {
      description = "Run lightning-charge";
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      serviceConfig = {
          EnvironmentFile = "/secrets/lightning-charge-api-token";
          ExecStart = "${pkgs.lightning-charge}/bin/charged -l ${config.services.clightning.dataDir} -d ${config.services.clightning.dataDir}/lightning-charge.db";
          # Unfortunately c-lightning doesn't allow setting the permissions of the rpc socket,
          # so this must run as the clightning user
          # https://github.com/ElementsProject/lightning/issues/1366
          User = "clightning";
          Restart = "on-failure";
          RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening
        // nix-bitcoin-services.nodejs
        // nix-bitcoin-services.allowTor;
    };
  };
}
