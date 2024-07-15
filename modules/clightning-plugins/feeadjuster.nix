{ config, lib, ... }:

with lib;
let
  options.services.clightning.plugins.feeadjuster = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable feeaduster (clightning plugin).
        This plugin auto-updates channel fees to keep channels balanced.

        See here for all available options:
        https://github.com/lightningd/plugins/blob/master/feeadjuster/feeadjuster.py
        Extra options can be set via `services.clightning.extraConfig`.
      '';
    };
    fuzz = mkOption {
      type = types.bool;
      default = true;
      description = "Enable update threshold randomization and hysteresis.";
    };
    adjustOnForward = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically update fees on forward events.";
    };
    method = mkOption {
      type = types.enum [ "soft" "default" "hard" ];
      default = "default";
      description = ''
        Adjustment method to calculate channel fees.
        `soft`: less difference when adjusting fees.
        `hard`: greater difference when adjusting fees.
      '';
    };
    adjustDaily = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically update fees daily.";
    };
  };

  cfg = config.services.clightning.plugins.feeadjuster;
  inherit (config.services) clightning;
in
{
  inherit options;

  config = mkIf (cfg.enable && clightning.enable) {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.feeadjuster.path}
      feeadjuster-adjustment-method="${cfg.method}"
    '' + optionalString (!cfg.fuzz) ''
      feeadjuster-deactivate-fuzz
    '' + optionalString (!cfg.adjustOnForward) ''
      feeadjuster-deactivate-fee-update
    '';

    systemd = mkIf cfg.adjustDaily {
      services.clightning-feeadjuster = {
        # Only run when clightning is running
        requisite = [ "clightning.service" ];
        after = [ "clightning.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "clightning";
          ExecStart = "${clightning.package}/bin/lightning-cli --lightning-dir ${clightning.dataDir} feeadjust";
        };
        unitConfig.JoinsNamespaceOf = [ "clightning.service" ];
        startAt = [ "daily" ];
      };
      timers.clightning-feeadjuster.timerConfig = {
        RandomizedDelaySec = "6h";
      };
    };
  };
}
