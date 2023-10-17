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
  # Remove bitcoin and bitcoind 24.1 packages and replace with 25.0 from nixpkgs
  # when https://github.com/bitcoin/bitcoin/issues/27722 has been resolved
  bitcoin  = pkgs.libsForQt5.callPackage ./bitcoin {
    stdenv = if pkgs.stdenv.isDarwin then pkgs.darwin.apple_sdk_11_0.stdenv else pkgs.stdenv;
    withGui = true;
    inherit (pkgs.darwin) autoSignDarwinBinariesHook;
  };

  bitcoind = pkgs.callPackage ./bitcoin {
    withGui = false;
    inherit (pkgs.darwin) autoSignDarwinBinariesHook;
  };
  clightning-rest = pkgs.callPackage ./clightning-rest { inherit (self) fetchNodeModules; };
  clboss = pkgs.callPackage ./clboss { };
  clightning-plugins = pkgs.recurseIntoAttrs (import ./clightning-plugins pkgs self.nbPython3Packages);
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3PackagesJoinmarket; };
  lndinit = pkgs.callPackage ./lndinit { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  rtl = pkgs.callPackage ./rtl { inherit (self) fetchNodeModules; };
  # The secp256k1 version used by joinmarket
  secp256k1 = pkgs.callPackage ./secp256k1 { };
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
