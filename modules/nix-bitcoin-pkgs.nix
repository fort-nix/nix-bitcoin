{ config, pkgs, ... }:
let
  nixpkgs-pinned = import ../pkgs/nixpkgs-pinned.nix;
  nixpkgs-unstable = import nixpkgs-pinned.nixpkgs-unstable { };
in {
  disabledModules = [ "services/security/tor.nix" ];
  imports = [
    (nixpkgs-pinned.nixpkgs-unstable + "/nixos/modules/services/security/tor.nix")
  ];

  nixpkgs.overlays = [ (import ../overlay.nix) ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Use bitcoin and clightning from unstable
    bitcoin = nixpkgs-unstable.bitcoin.override { miniupnpc = null; };
    blockchains.bitcoind = nixpkgs-unstable.bitcoind.override { miniupnpc = null; };
    clightning = nixpkgs-unstable.clightning.override { };
    lnd = nixpkgs-unstable.lnd.override { };
  };
}
