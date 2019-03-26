{ config, pkgs, ... }:
 let
   nixpkgs-pinned = import ../pkgs/nixpkgs-pinned.nix;
   nixpkgs-unstable = import nixpkgs-pinned.nixpkgs-unstable { };

   # Custom packages
   nodeinfo = pkgs.callPackage ../pkgs/nodeinfo { };
   banlist = pkgs.callPackage ../pkgs/banlist { };
   lightning-charge = pkgs.callPackage ../pkgs/lightning-charge { };
   nanopos = pkgs.callPackage ../pkgs/nanopos { };
   spark-wallet = pkgs.callPackage ../pkgs/spark-wallet { };
   electrs = pkgs.callPackage ../pkgs/electrs { };
   liquidd = pkgs.callPackage ../pkgs/liquidd { };
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
