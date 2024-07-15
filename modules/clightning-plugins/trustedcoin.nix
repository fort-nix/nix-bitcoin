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
      description = "The package providing trustedcoin binaries.";
    };

    tor.proxy = mkOption {
      type = types.bool;
      default = config.services.clightning.tor.proxy;
      description = "Whether to proxy outgoing connections with Tor.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning = {
      useBcliPlugin = false;
      extraConfig = ''
        plugin=${cfg.package}/bin/trustedcoin
      '';
      tor.enforce = mkIf (!cfg.tor.proxy) false;
    };

    systemd.services.clightning.environment = mkIf (cfg.tor.proxy) {
      HTTPS_PROXY = let
        clnProxy = config.services.clightning.proxy;
        proxy = if clnProxy != null then clnProxy else config.nix-bitcoin.torClientAddressWithPort;
      in
        "socks5://${proxy}";
    };
  };
}
