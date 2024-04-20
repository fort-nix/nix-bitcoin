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
  # TODO-EXTERNAL:
  # Remove bitcoin and bitcoind 26.x packages and replace with 27.0 from nixpkgs
  # when a version of lnd is released that is compatible with 27.0
  # (https://github.com/lightningnetwork/lnd/pull/8664).
  bitcoin = let inherit (pkgsUnstable) libsForQt5 stdenv darwin; in
    libsForQt5.callPackage ./bitcoin {
      stdenv = if stdenv.isDarwin then darwin.apple_sdk_11_0.stdenv else stdenv;
      withGui = true;
      inherit (darwin) autoSignDarwinBinariesHook;
  };

  bitcoind = let inherit (pkgsUnstable) callPackage darwin; in
    callPackage ./bitcoin {
      withGui = false;
      inherit (darwin) autoSignDarwinBinariesHook;
  };
  clightning-rest = pkgs.callPackage ./clightning-rest { inherit (self) fetchNodeModules; };
  clboss = pkgs.callPackage ./clboss { };
  clightning-plugins = pkgs.recurseIntoAttrs (import ./clightning-plugins pkgs self.nbPython3Packages);
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3PackagesJoinmarket; };
  lndinit = pkgs.callPackage ./lndinit { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  rtl = pkgs.callPackage ./rtl { inherit (self) fetchNodeModules; };
  inherit (pkgs.callPackage ./mempool { inherit (self) fetchNodeModules; })
    mempool-backend
    mempool-frontend
    mempool-nginx-conf;
  trustedcoin = pkgs.callPackage ./trustedcoin { };

  pyPkgs = import ./python-packages self pkgs.python3;
  inherit (self.pyPkgs)
    nbPython3Packages
    nbPython3PackagesJoinmarket;

  fetchNodeModules = pkgs.callPackage ./build-support/fetch-node-modules.nix { };

  # Internal pkgs
  netns-exec = pkgs.callPackage ./netns-exec { };
  krops = import ./krops { inherit pkgs; };

  # Deprecated pkgs
  generate-secrets = import ./generate-secrets-deprecated.nix;
  nixops19_09 = pkgs.callPackage ./nixops { };

  pinned = import ./pinned.nix pkgs pkgsUnstable;

  modulesPkgs = self // self.pinned;
}; in self
