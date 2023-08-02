{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.trustedcoin; in
{
  options.services.clightning.plugins.trustedcoin = {
    enable = mkEnableOption "Trustedcoin (clightning plugin)";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.trustedcoin;
      defaultText = "config.nix-bitcoin.pkgs.trustedcoin";
      description = mdDoc "The package providing trustedcoin binaries.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning = {
      useBcliPlugin = false;
      extraConfig = ''
        plugin=${cfg.package}/bin/trustedcoin
      '';
    };

    # Trustedcoin does not honor the clightning's proxy configuration.
    # Ref.: https://github.com/nbd-wtf/trustedcoin/pull/19
    systemd.services.clightning.environment = mkIf (config.services.clightning.proxy != null) {
      HTTPS_PROXY = "socks5://${config.services.clightning.proxy}";
    };
  };
}
