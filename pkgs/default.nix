{ pkgs }:

let
  getPkgs = p: let self = {
    spark-wallet = p.callPackage ./spark-wallet { };
    electrs = p.callPackage ./electrs { };
    elementsd = p.callPackage ./elementsd { withGui = false; };
    hwi = p.callPackage ./hwi { };
    liquid-swap = p.python3Packages.callPackage ./liquid-swap { };
    joinmarket = p.callPackage ./joinmarket { inherit (self) nbPython3Packages; };
    generate-secrets = p.callPackage ./generate-secrets { };
    # nixops19_09 = p.callPackage ./nixops { };
    netns-exec = p.callPackage ./netns-exec { };
    lightning-loop = p.callPackage ./lightning-loop { };
    extra-container = p.callPackage ./extra-container { };
    clightning-plugins = import ./clightning-plugins p self.nbPython3Packages;
    clboss = p.callPackage ./clboss { };
    secp256k1 = p.callPackage ./secp256k1 { };

    nbPython3Packages = (p.python3.override {
      packageOverrides = pySelf: super: import ./python-packages self pySelf;
    }).pkgs;

    pinned =
      {
        inherit (pkgs.unstable)
          bitcoin
          bitcoind
          clightning
          lnd
          lndconnect
          nbxplorer
          btcpayserver;

        stable = getPkgs pkgs;
        unstable = getPkgs pkgs.unstable;
      };

    modulesPkgs = self // self.pinned;
  }; in self;
in (getPkgs pkgs)
