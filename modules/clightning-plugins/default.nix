{ config, lib, pkgs, ... }:

with lib;
let
  options.services.clightning.plugins = {
    currencyrate.enable = mkEnableOption "Currencyrate (clightning plugin)";
    helpme.enable = mkEnableOption "Help me (clightning plugin)";
    monitor.enable = mkEnableOption "Monitor (clightning plugin)";
    rebalance.enable = mkEnableOption "Rebalance (clightning plugin)";
  };

  cfg = config.services.clightning.plugins;
  pluginPkgs = config.nix-bitcoin.pkgs.clightning-plugins;
in {
  imports = [
    ./clboss.nix
    ./feeadjuster.nix
    ./prometheus.nix
    ./summary.nix
    ./trustedcoin.nix
    ./teos-watchtower.nix
    ./zmq.nix
  ];

  inherit options;

  config = {
    services.clightning.extraConfig = mkMerge [
      (mkIf cfg.currencyrate.enable "plugin=${pluginPkgs.currencyrate.path}")
      (mkIf cfg.helpme.enable "plugin=${pluginPkgs.helpme.path}")
      (mkIf cfg.monitor.enable "plugin=${pluginPkgs.monitor.path}")
      (mkIf cfg.rebalance.enable "plugin=${pluginPkgs.rebalance.path}")
    ];
  };
}
