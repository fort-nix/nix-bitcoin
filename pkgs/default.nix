{ pkgs ? import <nixpkgs> {} }:
let self = {
  spark-wallet = pkgs.callPackage ./spark-wallet { };
  electrs = pkgs.callPackage ./electrs { };
  elementsd = pkgs.callPackage ./elementsd { withGui = false; };
  hwi = pkgs.callPackage ./hwi { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3Packages; };
  generate-secrets = pkgs.callPackage ./generate-secrets { };
  nixops19_09 = pkgs.callPackage ./nixops { };
  krops = import ./krops { };
  netns-exec = pkgs.callPackage ./netns-exec { };
  lightning-loop = pkgs.callPackage ./lightning-loop { };
  lightning-pool = pkgs.callPackage ./lightning-pool { };
  extra-container = pkgs.callPackage ./extra-container { };
  clightning-plugins = import ./clightning-plugins pkgs self.nbPython3Packages;
  clboss = pkgs.callPackage ./clboss { };
  secp256k1 = pkgs.callPackage ./secp256k1 { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = import ./python-packages self;
  }).pkgs;

  pinned = import ./pinned.nix;

  modulesPkgs = self // self.pinned;
}; in self
