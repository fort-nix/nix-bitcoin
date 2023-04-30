{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.circular; in
{
  options.services.clightning.plugins.circular = {
    enable = mkEnableOption "Circular (clightning plugin)";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.circular;
      defaultText = "config.nix-bitcoin.pkgs.circular";
      description = mdDoc "The package providing circular binary.";
    };
    graph-refresh = mkOption {
      type = types.ints.positive;
      default = 10;
      description = mdDoc "How often the graph is refreshed.";
    };
    peer-refresh = mkOption {
      type = types.ints.positive;
      default = 30;
      description = mdDoc "How often the list of peers is refreshed.";
    };
    liquidity-refresh = mkOption {
      type = types.ints.positive;
      default = 300;
      description = mdDoc "Period of time after which we consider a liquidity belief not valid anymore.";
    };
    save-stats = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Whether to save stats about the usage of the plugin.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/circular
    '';
  };
}