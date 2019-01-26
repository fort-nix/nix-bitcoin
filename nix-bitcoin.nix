{ config, pkgs, ... }:
 let
   nixpkgs-pinned = import ./nixpkgs-pinned.nix;
   nixpkgs-unstable = import nixpkgs-pinned.nixpkgs-unstable { };

   # Custom packages
   nodeinfo = (import pkgs/nodeinfo.nix) { inherit pkgs; };
   lightning-charge = import pkgs/lightning-charge.nix { inherit pkgs; };
   nanopos = import pkgs/nanopos.nix { inherit pkgs; };
   spark-wallet = import pkgs/spark-wallet.nix  { inherit pkgs; };
   electrs = pkgs.callPackage (import pkgs/electrs.nix) { };
   liquidd = pkgs.callPackage (import pkgs/liquidd.nix) { };
in {
  disabledModules = [ "services/security/tor.nix" ];
  imports = [
    ./modules/nix-bitcoin.nix
    (nixpkgs-pinned.nixpkgs-unstable + "/nixos/modules/services/security/tor.nix")
  ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Use bitcoin and clightning from unstable
    bitcoin = nixpkgs-unstable.bitcoin.override { };
    altcoins.bitcoind = nixpkgs-unstable.altcoins.bitcoind.override { };
    clightning = nixpkgs-unstable.clightning.override { };

    # Add custom packages
    inherit nodeinfo;
    inherit lightning-charge;
    inherit nanopos;
    inherit spark-wallet;
    inherit electrs;
    inherit liquidd;
  };
}
