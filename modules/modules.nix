{ config, pkgs, ... }:
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
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];

  nixpkgs.overlays = [ (self: super: {
    nix-bitcoin = allPackages super;
  }) ];
}
