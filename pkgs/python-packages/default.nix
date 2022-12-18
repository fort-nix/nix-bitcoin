nbPkgs: self: super:
let
  inherit (self) callPackage;

  joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };

  unstable = (import ../nixpkgs-pinned.nix).nixpkgs-unstable;
in {
      bencoderpyx = callPackage ./bencoderpyx {};
      chromalog = callPackage ./chromalog {};
      coincurve = callPackage ./coincurve {};
      python-bitcointx = callPackage ./python-bitcointx { inherit (nbPkgs) secp256k1; };
      runes = callPackage ./runes {};
      sha256 = callPackage ./sha256 {};
      txzmq = callPackage ./txzmq {};
      urldecode = callPackage ./urldecode {};

      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

      pyln-client = clightningPkg ./pyln-client;
      pyln-proto = clightningPkg ./pyln-proto;
      pyln-bolt7 = clightningPkg ./pyln-bolt7;
      pylightning = clightningPkg ./pylightning;

      # Don't mark `klein` as broken.
      # `klein` is fixed by using werkzeug 2.1.0 (see below)
      klein = super.klein.overrideAttrs (old: {
        meta = builtins.removeAttrs old.meta [ "broken" ];
      });

      ## Specific versions of packages that already exist in nixpkgs

      # cryptography 3.3.2, required by joinmarketdaemon
      # Used in the private python package set for joinmarket (../joinmarket/default.nix)
      cryptography_3_3_2 = callPackage ./specific-versions/cryptography {
        cryptography_vectors = callPackage ./specific-versions/cryptography/vectors.nix {};
      };

      # autobahn 20.12.3, required by joinmarketclient
      autobahn = callPackage ./specific-versions/autobahn.nix {};

      # werkzeug 2.1.0, required by jmclient (via pkg `klein`)
      werkzeug = callPackage ./specific-versions/werkzeug.nix {};

      # pyopenssl 20.0.1, required by joinmarketdaemon
      pyopenssl = callPackage ./specific-versions/pyopenssl.nix {};
}
