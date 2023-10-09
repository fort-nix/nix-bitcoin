{ config, lib, ... }:

with lib;
let cfg = config.services.clightning.plugins.teos-watchtower; in
{
  # Ref.: https://github.com/talaia-labs/rust-teos/tree/master/watchtower-plugin
  options.services.clightning.plugins.teos-watchtower = {
    enable = mkEnableOption "TEoS watchtower (clightning plugin)";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.teos-watchtower-plugin;
      defaultText = "config.nix-bitcoin.pkgs.teos-watchtower-plugin";
      description = mdDoc "The package providing TEoS watchtower plugin binaries.";
    };
    port = mkOption {
      type = types.port;
      default = config.services.teos.api.port;
      description = mdDoc "Tower API port.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "${config.services.clightning.dataDir}/.watchtower";
      description = mdDoc "The data directory for teos-watchtower.";
    };
    maxRetryTime = mkOption {
      type = types.int;
      default = 3600;
      description = mdDoc "For how long (in seconds) a retry strategy will try to reach a temporary unreachable tower before giving up.";
    };
    autoRetryDelay = mkOption {
      type = types.int;
      default = 28800;
      description = mdDoc "For how long (in seconds) the client will wait before auto-retrying a failed tower.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/watchtower-client
      watchtower-port=${toString cfg.port}
      watchtower-max-retry-time=${toString cfg.maxRetryTime}
      watchtower-auto-retry-delay=${toString cfg.autoRetryDelay}
    '';

    # The data directory of teos-watchtower must be specified and must
    # be writeable. Otherwise the plugin fails to load.
    systemd.services.clightning.environment = {
      TOWERS_DATA_DIR = cfg.dataDir;
    };
  };
}
