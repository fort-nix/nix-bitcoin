let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
in
# Set default values for use without flakes
{ pkgs ? import <nixpkgs> { config = {}; overlays = []; }
, pkgsUnstable ? import nixpkgsPinned.nixpkgs-unstable { config = {}; overlays = []; }
}:
let self = {
  cl-rest = pkgs.callPackage ./cl-rest { };
  clboss = pkgs.callPackage ./clboss { };
  clightning-plugins = pkgs.recurseIntoAttrs (import ./clightning-plugins pkgs self.nbPython3Packages);
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3Packages; };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  rtl = pkgs.callPackage ./rtl { };
  secp256k1 = pkgs.callPackage ./secp256k1 { };
  spark-wallet = pkgs.callPackage ./spark-wallet { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = import ./python-packages self;
  }).pkgs;

  # Internal pkgs
  netns-exec = pkgs.callPackage ./netns-exec { };
  krops = import ./krops { };

  # Deprecated pkgs
  generate-secrets = import ./generate-secrets-deprecated.nix;
  nixops19_09 = pkgs.callPackage ./nixops { };

  pinned = import ./pinned.nix pkgs pkgsUnstable;

  modulesPkgs = self // self.pinned;
}; in self
