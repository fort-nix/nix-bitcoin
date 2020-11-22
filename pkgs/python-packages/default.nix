nbPkgs:
self:
let
  inherit (self) callPackage;

  joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
in {
  bencoderpyx = callPackage ./bencoderpyx {};
  coincurve = callPackage ./coincurve {};
  python-bitcointx = callPackage ./python-bitcointx {};
  secp256k1 = callPackage ./secp256k1 {};
  urldecode = callPackage ./urldecode {};
  chromalog = callPackage ./chromalog {};
  txzmq = callPackage ./txzmq {};

  joinmarketbase = joinmarketPkg ./jmbase;
  joinmarketclient = joinmarketPkg ./jmclient;
  joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
  joinmarketdaemon = joinmarketPkg ./jmdaemon;

  pyln-client = clightningPkg ./pyln-client;
  pyln-proto = clightningPkg ./pyln-proto;
  pylightning = clightningPkg ./pylightning;
}
