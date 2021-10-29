{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.clightning.plugins.backup;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  clightningCfg = config.services.clightning;
  backupPkg = nbPkgs.clightning-plugins.backup;
in
{
  options.services.clightning.plugins.backup = {
    enable = mkEnableOption "backup (clightning plugin)";
    backendURL = mkOption {
      type = types.str;
      default = "";
      description = "Location of the backup";
      example = "file:///mnt/external/location/file.bkp";
    };
    inherit (nbLib) enforceTor;
  };
  config = mkIf cfg.enable {
    assertions = [
      { assertion = cfg.backendURL != "";
        message = "You must set system.services.clightning.plugins.backup.backendURL";
      }
    ];
    services.clightning.extraConfig = ''
      important-plugin=${backupPkg.path}
    '';
     systemd.services.clightning-backup-init = {
        description = "Run backup-cli init";
        wantedBy = [ "clightning.service" ];
        partOf = [ "clightning.service" ];
        before = [ "clightning.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = clightningCfg.user;
        };
        script = ''
          backendURL="${cfg.backendURL}"
          backupLock="${clightningCfg.networkDir}/backup.lock"
          if [[ ! -e $backupLock || $backendURL != $(cat $backupLock | ${pkgs.jq}/bin/jq -r .backend_url) ]]; then
            umask u=rw,go=
            ${backupPkg}/backup-cli init --lightning-dir "${clightningCfg.networkDir}" ${cfg.backendURL}
          fi
         '';
      };
  };
}
