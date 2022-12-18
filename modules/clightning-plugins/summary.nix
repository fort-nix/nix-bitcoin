{ config, lib, ... }:

with lib;
let cfg = config.services.clightning.plugins.summary; in
{
  options.services.clightning.plugins.summary = {
    enable = mkEnableOption "Summary (clightning plugin)";
    currency = mkOption {
      type = types.str;
      default = "USD";
      description = mdDoc "The currency to look up on btcaverage.";
    };
    currencyPrefix = mkOption {
      type = types.str;
      default = "USD $";
      description = mdDoc "The prefix to use for the currency.";
    };
    availabilityInterval = mkOption {
      type = types.int;
      default = 300;
      description = mdDoc "How often in seconds the availability should be calculated.";
    };
    availabilityWindow = mkOption {
      type = types.int;
      default = 72;
      description = mdDoc "How many hours the availability should be averaged over.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.summary.path}
      summary-currency="${cfg.currency}"
      summary-currency-prefix="${cfg.currencyPrefix}"
      summary-availability-interval=${toString cfg.availabilityInterval}
      summary-availability-window=${toString cfg.availabilityWindow}
    '';
  };
}
