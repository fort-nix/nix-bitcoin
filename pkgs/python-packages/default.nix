nbPkgs: self: super:
let
  inherit (self) callPackage;

  joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };

  unstable = (import ../nixpkgs-pinned.nix).nixpkgs-unstable;
in {
  bech32 = callPackage ./bech32 {};
  bencoderpyx = callPackage ./bencoderpyx {};
  chromalog = callPackage ./chromalog {};
  coincurve = callPackage ./coincurve {};
  embit = callPackage ./embit {};
  lnurl = callPackage ./lnurl {};
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

  represent = callPackage ./represent {};
  sqlalchemy-aio = callPackage ./sqlalchemy-aio {};
  sse-starlette = callPackage ./sse-starlette {};

  ## Specific versions of packages that already exist in nixpkgs

  # cryptography 3.3.2, required by joinmarketdaemon
  # Used in the private python package set for joinmarket (../joinmarket/default.nix)
  cryptography_3_3_2 = callPackage ./specific-versions/cryptography {
    cryptography_vectors = callPackage ./specific-versions/cryptography/vectors.nix {};
  };

  # cryptography 36.0.0, required by pyln-proto.
  cryptography = callPackage "${unstable}/pkgs/development/python-modules/cryptography" {
    Security = self.darwin.apple_sdk.frameworks.Security;
  };

  # autobahn 20.12.3, required by joinmarketclient
  autobahn = callPackage ./specific-versions/autobahn.nix {};

  # tubes 0.2.0, required by jmclient (via pkg `klein`)
  tubes = callPackage ./specific-versions/tubes.nix {};

  # recommonmark 0.7.1, required by pyln-client
  recommonmark = callPackage ./specific-versions/recommonmark.nix { inherit (super) recommonmark; };

  # sqlalchemy 1.3.23, required by lnbits
  sqlalchemy_1_3_23 = callPackage ./specific-versions/sqlalchemy.nix {};
}
