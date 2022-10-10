let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
in
# Set default values for use without flakes
{ pkgs ? import <nixpkgs> { config = {}; overlays = []; }
, pkgsUnstable ? import nixpkgsPinned.nixpkgs-unstable {
    inherit (pkgs.stdenv) system;
    config = {};
    overlays = [];
  }
}:
let self = {
  clightning-rest = pkgs.callPackage ./clightning-rest { inherit (self) fetchNodeModules; };
  clboss = pkgs.callPackage ./clboss { };
  clightning-plugins = pkgs.recurseIntoAttrs (import ./clightning-plugins pkgs self.nbPython3Packages);
  joinmarket = pkgs.callPackage ./joinmarket { nbPythonPackageOverrides = import ./python-packages self; };
  lndinit = pkgs.callPackage ./lndinit { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  rtl = pkgs.callPackage ./rtl { inherit (self) fetchNodeModules; };
  # The secp256k1 version used by joinmarket
  secp256k1 = pkgs.callPackage ./secp256k1 { };
  spark-wallet = pkgs.callPackage ./spark-wallet { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = import ./python-packages self;
  }).pkgs;

  fetchNodeModules = pkgs.callPackage ./build-support/fetch-node-modules.nix { };

  # Internal pkgs
  netns-exec = pkgs.callPackage ./netns-exec { };
  krops = import ./krops { inherit pkgs; };

  # Deprecated pkgs
  generate-secrets = import ./generate-secrets-deprecated.nix;
  nixops19_09 = pkgs.callPackage ./nixops { };

  pinned = import ./pinned.nix pkgs pkgsUnstable;

  # TODO-EXTERNAL:
  # Remove this when https://github.com/NixOS/nixpkgs/pull/195337 is available in the
  # nixpkgs-unstable channel
  lnd = pkgsUnstable.callPackage ./lnd-0.15.2.nix {};

  modulesPkgs = self // self.pinned;
}; in self
