{ config, lib, pkgs, ... }:

with lib;
let
  options.services.bitcoin-tui = {
    enable = mkEnableOption "bitcoin-tui, a terminal UI dashboard for Bitcoin Core";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.bitcoin-tui or (pkgs.callPackage ../pkgs/bitcoin-tui {});
      description = "The bitcoin-tui package to use.";
    };
  };

  cfg = config.services.bitcoin-tui;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind.enable = true;

    environment.systemPackages = [ cfg.package ];

    nix-bitcoin.operator.groups = [ "bitcoinrpc-public" ];
  };
}
