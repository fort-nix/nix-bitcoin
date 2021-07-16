{ pkgs ? import <nixpkgs> {} }:
let self = {
  spark-wallet = pkgs.callPackage ./spark-wallet { };
  elementsd = pkgs.callPackage ./elementsd { withGui = false; };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3Packages; };
  generate-secrets = pkgs.callPackage ./generate-secrets { };
  nixops19_09 = pkgs.callPackage ./nixops { };
  krops = import ./krops { };
  netns-exec = pkgs.callPackage ./netns-exec { };
  extra-container = pkgs.callPackage ./extra-container { };
  clightning-plugins = import ./clightning-plugins pkgs self.nbPython3Packages;
  clboss = pkgs.callPackage ./clboss { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = import ./python-packages self;
  }).pkgs;

  pinned = import ./pinned.nix;

  modulesPkgs = self // self.pinned;
}; in self
