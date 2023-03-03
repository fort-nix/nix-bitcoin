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
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/trustedcoin
      disable-plugin=bcli
    '';
  };
}
