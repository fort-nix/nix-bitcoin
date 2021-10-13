{ stdenv, lib, fetchurl, python3, nbPython3Packages, pkgs }:

let
  version = "0.9.2";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
    sha256 = "0nzhnf2324d0qc9pljcjwpzpvhcclqg0ijvzb1skmn73s4f25akg";
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

    ## ob-watcher
    obw=$out/libexec/joinmarket-ob-watcher
    install -D scripts/obwatch/ob-watcher.py $obw/ob-watcher
    patchShebangs $obw/ob-watcher
    ln -s $obw/ob-watcher $out/bin/jm-ob-watcher

    # These files must be placed in the same dir as ob-watcher
    cp -r scripts/obwatch/{orderbook.html,sybil_attack_calculations.py,vendor} $obw
  '';
}
