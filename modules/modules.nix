{ config, pkgs, lib, ... }:
let
  nixpkgs-pinned = import ../pkgs/nixpkgs-pinned.nix;
  unstable = import nixpkgs-pinned.nixpkgs-unstable {};

  allPackages = pkgs: (import ../pkgs { inherit pkgs; }) // {
    bitcoin = unstable.bitcoin.override { miniupnpc = null; };
    bitcoind = unstable.bitcoind.override { miniupnpc = null; };
    clightning = unstable.clightning;
    lnd = unstable.lnd;
  };
in {
  imports = [
    ./bitcoind.nix
    ./clightning.nix
    ./lightning-charge.nix
    ./nanopos.nix
    ./nix-bitcoin-webindex.nix
    ./liquid.nix
    ./spark-wallet.nix
    ./electrs.nix
    ./onion-chef.nix
    ./recurring-donations.nix
    ./hardware-wallets.nix
    ./lnd.nix
    ./secrets/secrets.nix
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];

  options = {
    nix-bitcoin-services = lib.mkOption {
      readOnly = true;
      default = import ./nix-bitcoin-services.nix lib;
    };
  };

  config = {
    nixpkgs.overlays = [ (self: super: {
      nix-bitcoin = allPackages super;
    }) ];
  };
}
