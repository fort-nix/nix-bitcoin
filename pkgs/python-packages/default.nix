nbPkgs: python3:
let
  # Ignore eval error:
  # `OpenSSL 1.1 is reaching its end of life on 2023/09/11 and cannot
  # be supported through the NixOS 23.05 release cycle.`
  # TODO-EXTERNAL: consider removing when
  # https://github.com/Simplexum/python-bitcointx/issues/76 and
  # https://github.com/JoinMarket-Org/joinmarket-clientserver#1451 are resolved.
  openssl_1_1 = python3.pkgs.pkgs.openssl_1_1.overrideAttrs (old: {
    meta = builtins.removeAttrs old.meta [ "knownVulnerabilities" ];
  });
in
rec {
  pyPkgsOverrides = self: super: let
    inherit (self) callPackage;
    clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
  in
    {
      txzmq = callPackage ./txzmq {};

      pyln-client = clightningPkg ./pyln-client;
      pyln-proto = clightningPkg ./pyln-proto;
      pyln-bolt7 = clightningPkg ./pyln-bolt7;
      pylightning = clightningPkg ./pylightning;

      # cryptography 41, required by pyln-proto
      cryptography = callPackage ./specific-versions/cryptography_41 {
        Security = super.darwin.apple_sdk.frameworks.Security;
      };

      # The versions of these packages that ship with nixos-23.05 are incompatible
      # with cryptography 41
      pyopenssl = callPackage ./specific-versions/pyopenssl_23_2 {};
      service-identity = callPackage ./specific-versions/service-identity_23_1 {};

      # The twisted package in nixos-23.05 runs a test that fails with
      # service-identity 23.1. This package is backported from nixos-unstable
      # and disables the test. (see
      # https://github.com/twisted/twisted/issues/11877,
      # https://github.com/NixOS/nixpkgs/commit/1ee622b10fcafcf2343960e3ffae0169afc59804)
      twisted = callPackage ./specific-versions/twisted_22_10 {};

      # Used by cryptography 41, backported from nixpkgs-unstable
      setuptoolsRustBuildHook = callPackage ./setuptools-rust-hook {};

      # bitstring 3.1.9, required by pyln-proto
      bitstring = callPackage ./specific-versions/bitstring.nix {};

      # Packages only used by joinmarket
      bencoderpyx = callPackage ./bencoderpyx {};
      chromalog = callPackage ./chromalog {};
      python-bitcointx = callPackage ./python-bitcointx {
        inherit (nbPkgs) secp256k1;
        openssl = openssl_1_1;
      };
      runes = callPackage ./runes {};
      sha256 = callPackage ./sha256 {};
    };

  # Joinmarket requires a custom package set because it uses older versions of Python pkgs
  pyPkgsOverridesJoinmarket = self: super: let
    inherit (self) callPackage;
    joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  in
    (pyPkgsOverrides self super) // {
      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

      ## Specific versions of packages that already exist in nixpkgs

      # autobahn 20.12.3, required by joinmarketclient
      autobahn = callPackage ./specific-versions/autobahn.nix {};

      # txtorcon 22.0.0, required by joinmarketdaemon
      txtorcon = callPackage ./specific-versions/txtorcon.nix {};
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

  nbPython3PackagesJoinmarket = (python3.override {
    packageOverrides = pyPkgsOverridesJoinmarket;
  }).pkgs;
}
