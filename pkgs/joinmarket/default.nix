{ stdenv, lib, fetchurl, python3, nbPython3Packages, pkgs }:

let
  version = "0.8.1";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
    sha256 = "1q3x1x0a78v6apwvbyhl7yh4dgr7xpikd8j07gi3by004ns3789d";
  };

  runtimePackages = with nbPython3Packages; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
    matplotlib # for ob-watcher
  ];

  pythonEnv = python3.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src;

  buildInputs = [ pythonEnv ];

  installPhase = ''
    mkdir -p $out/bin

    # add-utxo.py -> bin/jm-add-utxo
    cpBin() {
      cp scripts/$1 $out/bin/jm-''${1%.py}
    }

    cp scripts/joinmarketd.py $out/bin/joinmarketd
    cp scripts/obwatch/ob-watcher.py $out/bin/ob-watcher
    cpBin add-utxo.py
    cpBin convert_old_wallet.py
    cpBin receive-payjoin.py
    cpBin sendpayment.py
    cpBin sendtomany.py
    cpBin tumbler.py
    cpBin wallet-tool.py
    cpBin yg-privacyenhanced.py
    cpBin genwallet.py

    chmod +x -R $out/bin
    patchShebangs $out/bin

    # This file must be placed in the same dir as ob-watcher
    cp scripts/obwatch/orderbook.html $out/bin/orderbook.html
  '';
}
