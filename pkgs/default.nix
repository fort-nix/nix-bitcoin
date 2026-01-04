let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
in
# Set default values for use without flakes
{ pkgs ? import <nixpkgs> { config = {}; overlays = []; }
, pkgsUnstable ? import nixpkgsPinned.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {};
    overlays = [];
  }
, pkgs-25_05 ? import nixpkgsPinned.nixpkgs-25_05 {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {};
    overlays = [];
  }
}:
let self = {
  clightning-rest = pkgs.callPackage ./clightning-rest { inherit (self) fetchNodeModules; };
  clightning-plugins = pkgs.lib.recurseIntoAttrs (import ./clightning-plugins pkgs self.nbPython3Packages);
  clnrest = pkgs.callPackage ./clnrest { inherit (self.pinned) clightning; };
  joinmarket = pkgs.callPackage ./joinmarket { inherit (self) nbPython3PackagesJoinmarket; };
  lndinit = pkgs.callPackage ./lndinit { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  nbxplorer = pkgs.callPackage ./nbxplorer { };
  rtl = pkgs.callPackage ./rtl { inherit (self) fetchNodeModules; };
  inherit (pkgs.callPackage ./mempool { inherit (self) fetchNodeModules; })
    mempool-backend
    mempool-frontend
    mempool-rust-gbt
    mempool-nginx-conf;
  trustedcoin = pkgs.callPackage ./trustedcoin { };

  bitcoind_29 = pkgs.callPackage ./bitcoind_29 {};
  inherit (self.pyPkgs.nbPython3PackagesWithUnlockedEcdsa) hwi;

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

  pinned = import ./pinned.nix pkgs pkgsUnstable pkgs-25_05;

  modulesPkgs = self // self.pinned;
}; in self
