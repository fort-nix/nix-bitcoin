{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.clboss; in
{
  options.services.clightning.plugins.clboss = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable CLBOSS (clightning plugin).
        See also: https://github.com/ZmnSCPxj/clboss#operating
      '';
    };
    min-onchain = mkOption {
      type = types.ints.positive;
      default = 30000;
      description = ''
        Target amount (in satoshi) that CLBOSS will leave on-chain.
        clboss will only open new channels if the funds in your clightning wallet are
        larger than this amount.
      '';
    };
    min-channel = mkOption {
      type = types.ints.positive;
      default = 500000;
      description = "The minimum size (in satoshi) of channels created by CLBOSS.";
    };
    max-channel = mkOption {
      type = types.ints.positive;
      default = 16777215;
      description = "The maximum size (in satoshi) of channels created by CLBOSS.";
    };
    zerobasefee = mkOption {
      type = types.enum [ "require" "allow" "disallow" ];
      default = "allow";
      description = ''
        `require`: set `base_fee` to 0.
        `allow`: set `base_fee` according to the CLBOSS heuristics, which may include value 0.
        `disallow`: set `base_fee` to according to the CLBOSS heuristics, with a minimum value of 1.
      '';
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.clboss;
      defaultText = "config.nix-bitcoin.pkgs.clboss";
      description = "The package providing clboss binaries.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/clboss
      clboss-min-onchain=${toString cfg.min-onchain}
      clboss-min-channel=${toString cfg.min-channel}
      clboss-max-channel=${toString cfg.max-channel}
      clboss-zerobasefee=${cfg.zerobasefee}
    '';

    systemd.services.clightning.path = [
      pkgs.dnsutils
    ] ++ optional config.services.clightning.tor.proxy (hiPrio config.nix-bitcoin.torify);
  };
}
