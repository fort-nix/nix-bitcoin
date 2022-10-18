{ config, lib, ... }:

with lib;
let cfg = config.services.clightning.plugins.teos-watchtower-plugin; in
{
  options.services.clightning.plugins.teos-watchtower-plugin = {
    enable = mkEnableOption "TEoS - watchtower (clightning plugin)";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.teos-watchtower-plugin;
      defaultText = "config.nix-bitcoin.pkgs.teos-watchtower-plugin";
      description = mdDoc "The package providing TEoS watchtower plugin binaries.";
    };
    port = mkOption {
      type = types.port;
      default = config.services.teos.api.port;
      description = mdDoc "tower API port.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "${config.services.clightning.dataDir}/.watchtower";
      description = mdDoc "The data directory for teos-watchtower-plugin.";
    };
    watchtowerMaxRetryTime = mkOption {
      type = types.int;
      default = 900;
      description = mdDoc "the maximum time a retry strategy will try to reach a temporary unreachable tower before giving up.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/watchtower-client
      watchtower-port=${toString cfg.port}
      watchtower-max-retry-time=${toString cfg.watchtowerMaxRetryTime}
    '';

    # The data directory of teos-watchtower-plugin must be specified and must
    # be writeable. Otherwise the plugin fails to load.
    systemd.services.clightning.environment = {
      TOWERS_DATA_DIR = cfg.dataDir;
    };
  };
}
