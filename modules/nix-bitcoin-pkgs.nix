{ config, pkgs, ... }:
let
  nixpkgs-pinned = import ../pkgs/nixpkgs-pinned.nix;
  nixpkgs-unstable = import nixpkgs-pinned.nixpkgs-unstable { };
in {
  disabledModules = [ "services/networking/bitcoind.nix" ];

  nixpkgs.overlays = [ (import ../overlay.nix) ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Use bitcoin and clightning from unstable
    bitcoin = nixpkgs-unstable.bitcoin.override { miniupnpc = null; };
    blockchains.bitcoind = nixpkgs-unstable.bitcoind.override { miniupnpc = null; };
    clightning = nixpkgs-unstable.clightning.override { };
    lnd = nixpkgs-unstable.lnd.override { };
  };
}
