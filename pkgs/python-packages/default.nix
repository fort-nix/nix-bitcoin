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

  joinmarketbase = joinmarketPkg ./jmbase;
  joinmarketclient = joinmarketPkg ./jmclient;
  joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
  joinmarketdaemon = joinmarketPkg ./jmdaemon;

  pyln-client = clightningPkg ./pyln-client;
  pyln-proto = clightningPkg ./pyln-proto;
  pyln-bolt7 = clightningPkg ./pyln-bolt7;
  pylightning = clightningPkg ./pylightning;

  ## Specific versions of packages that already exist in nixpkgs

  # cryptography 3.3.2, required by joinmarketdaemon
  cryptography = callPackage ./specific-versions/cryptography {};
  cryptography_vectors = callPackage ./specific-versions/cryptography/vectors.nix {};

  # autobahn 20.12.3, required by joinmarketclient
  autobahn = callPackage ./specific-versions/autobahn.nix {};

  # klein 20.6.0, required by joinmarketclient
  klein = callPackage ./specific-versions/klein.nix {};

  # tubes 0.2.0, required by klein
  tubes = callPackage ./specific-versions/tubes.nix {};

  # recommonmark 0.7.1, required by pyln-client
  recommonmark = callPackage ./specific-versions/recommonmark.nix { inherit (super) recommonmark; };
}
