nbPkgs: python3:
rec {
  pyPkgsOverrides = self: super: let
    inherit (self) callPackage;
    clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
  in
    {
      coincurve = callPackage ./coincurve {};
      txzmq = callPackage ./txzmq {};

      pyln-client = clightningPkg ./pyln-client;
      pyln-proto = clightningPkg ./pyln-proto;
      pyln-bolt7 = clightningPkg ./pyln-bolt7;
      pylightning = clightningPkg ./pylightning;

      # Packages only used by joinmarket
      bencoderpyx = callPackage ./bencoderpyx {};
      chromalog = callPackage ./chromalog {};
      python-bitcointx = callPackage ./python-bitcointx {
        inherit (nbPkgs) secp256k1;
        openssl = super.pkgs.openssl_1_1;
      };
      runes = callPackage ./runes {};
      sha256 = callPackage ./sha256 {};
      urldecode = callPackage ./urldecode {};
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

      # cryptography 3.3.2, required by joinmarketdaemon
      # Used in the private python package set for joinmarket (../joinmarket/default.nix)
      cryptography = callPackage ./specific-versions/cryptography {
        openssl = super.pkgs.openssl_1_1;
        cryptography_vectors = callPackage ./specific-versions/cryptography/vectors.nix {};
      };

      # autobahn 20.12.3, required by joinmarketclient
      autobahn = callPackage ./specific-versions/autobahn.nix {};

      # pyopenssl 20.0.1, required by joinmarketdaemon
      pyopenssl = callPackage ./specific-versions/pyopenssl.nix {
        openssl = super.pkgs.openssl_1_1;
      };

      # twisted 22.4.0, compatible with pyopenssl 20.0.1
      twisted = callPackage ./specific-versions/twisted.nix {};
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

  nbPython3PackagesJoinmarket = (python3.override {
    packageOverrides = pyPkgsOverridesJoinmarket;
  }).pkgs;
}
