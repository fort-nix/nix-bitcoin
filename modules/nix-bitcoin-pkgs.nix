{ config, pkgs, ... }:
 let
   nixpkgs-pinned = import ../pkgs/nixpkgs-pinned.nix;
   nixpkgs-unstable = import nixpkgs-pinned.nixpkgs-unstable { };

   # Custom packages
   nodeinfo = (import ../pkgs/nodeinfo.nix) { inherit pkgs; };
   banlist = (import ../pkgs/banlist.nix) { inherit pkgs; };
   lightning-charge = pkgs.callPackage ../pkgs/lightning-charge { };
   nanopos = pkgs.callPackage ../pkgs/nanopos { };
   spark-wallet = pkgs.callPackage ../pkgs/spark-wallet { };
   electrs = pkgs.callPackage (import ../pkgs/electrs.nix) { };
   liquidd = pkgs.callPackage (import ../pkgs/liquidd.nix) { };
in {
  disabledModules = [ "services/security/tor.nix" ];
  imports = [
    (nixpkgs-pinned.nixpkgs-unstable + "/nixos/modules/services/security/tor.nix")
  ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Use bitcoin and clightning from unstable
    bitcoin = nixpkgs-unstable.bitcoin.override { };
    altcoins.bitcoind = nixpkgs-unstable.altcoins.bitcoind.override { };
    clightning = nixpkgs-unstable.clightning.override { };

    # Add custom packages
    inherit nodeinfo;
    inherit banlist;
    inherit lightning-charge;
    inherit nanopos;
    inherit spark-wallet;
    inherit electrs;
    inherit liquidd;
  };
}
