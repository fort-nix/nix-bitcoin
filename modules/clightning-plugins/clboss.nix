{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.clboss; in
{
  options.services.clightning.plugins.clboss = {
    enable = mkEnableOption "CLBOSS (clightning plugin)";
    min-onchain = mkOption {
      type = types.ints.positive;
      default = 30000;
      description = ''
        Target amount (in satoshi) that CLBOSS will leave on-chain.
        clboss will only open new channels if this amount is smaller than
        the funds in your clightning wallet.
      '';
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.clboss;
      description = "The package providing clboss binaries.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/clboss
      clboss-min-onchain=${toString cfg.min-onchain}
    '';
    systemd.services.clightning.path = [
      pkgs.dnsutils
    ] ++ optional config.services.clightning.enforceTor (hiPrio config.nix-bitcoin.torify);
  };
}
