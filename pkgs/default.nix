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
  netns-exec = pkgs.callPackage ./netns-exec { };
  lightning-loop = pkgs.callPackage ./lightning-loop { };
  faraday = pkgs.callPackage ./faraday { };
  extra-container = pkgs.callPackage ./extra-container { };
  clightning-plugins = import ./clightning-plugins pkgs self.nbPython3Packages;
  clboss = pkgs.callPackage ./clboss { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = pySelf: super: import ./python-packages self pySelf;
  }).pkgs;

  pinned = import ./pinned.nix;

  modulesPkgs = self // self.pinned;
}; in self
