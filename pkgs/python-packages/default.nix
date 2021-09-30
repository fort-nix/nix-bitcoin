nbPkgs: self: super:
let
  inherit (self) callPackage;

  joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
in {
  bencoderpyx = callPackage ./bencoderpyx {};
  coincurve = callPackage ./coincurve {};
  python-bitcointx = callPackage ./python-bitcointx { inherit (nbPkgs) secp256k1; };
  urldecode = callPackage ./urldecode {};
  chromalog = callPackage ./chromalog {};
  txzmq = callPackage ./txzmq {};
  recommonmark = callPackage ./recommonmark { inherit (super) recommonmark; };

  # cryptography 3.3.2, required by joinmarketdaemon
  cryptography = callPackage ./cryptography {};
  cryptography_vectors = callPackage ./cryptography/vectors.nix {};

  # twisted 20.3.0, required by joinmarketbase
  twisted = callPackage ./twisted {};

  joinmarketbase = joinmarketPkg ./jmbase;
  joinmarketclient = joinmarketPkg ./jmclient;
  joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
  joinmarketdaemon = joinmarketPkg ./jmdaemon;

  pyln-client = clightningPkg ./pyln-client;
  pyln-proto = clightningPkg ./pyln-proto;
  pylightning = clightningPkg ./pylightning;

  # squeakpy 0.7.7, required by squeaknode
  squeakpy = callPackage ./squeakpy {};
  # typed-config 0.2.5, required by squeaknode
  typed-config = callPackage ./typed-config {};
}
