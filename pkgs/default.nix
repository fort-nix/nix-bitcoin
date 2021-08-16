let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
in
# Set default values for use without flakes
{ pkgs ? import <nixpkgs> { config = {}; overlays = []; }
, pkgsUnstable ? import nixpkgsPinned.nixpkgs-unstable { config = {}; overlays = []; }
}:
let self = {
  spark-wallet = pkgs.callPackage ./spark-wallet { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3Packages; };
  generate-secrets = pkgs.callPackage ./generate-secrets { };
  nixops19_09 = pkgs.callPackage ./nixops { };
  krops = import ./krops { };
  netns-exec = pkgs.callPackage ./netns-exec { };
  extra-container = pkgs.callPackage ./extra-container { };
  clightning-plugins = import ./clightning-plugins pkgs self.nbPython3Packages;
  clboss = pkgs.callPackage ./clboss { };
  secp256k1 = pkgs.callPackage ./secp256k1 { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = import ./python-packages self;
  }).pkgs;

  pinned = import ./pinned.nix pkgs pkgsUnstable;

  modulesPkgs = self // self.pinned;
}; in self
