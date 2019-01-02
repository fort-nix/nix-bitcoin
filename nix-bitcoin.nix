{ config, pkgs, ... }:
 let
   unstable-pkgs-git = builtins.fetchGit {
     url = "https://github.com/nixos/nixpkgs-channels";
     ref = "nixos-unstable";
     rev = "201d739b0ffbebceb444864d1856babcd1a666a8";
   };
   unstable-pkgs = import unstable-pkgs-git { };

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
    (unstable-pkgs-git + "/nixos/modules/services/security/tor.nix")
  ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Use bitcoin and clightning from unstable
    bitcoin = unstable-pkgs.bitcoin.override { };
    altcoins.bitcoind = unstable-pkgs.altcoins.bitcoind.override { };
    clightning = unstable-pkgs.clightning.override { };

    # Add custom packages
    inherit nodeinfo;
    inherit lightning-charge;
    inherit nanopos;
    inherit spark-wallet;
    inherit electrs;
    inherit liquidd;
  };
}
