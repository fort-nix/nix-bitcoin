{ stdenv, lib, fetchurl, applyPatches, fetchpatch, python3, nbPython3Packages, pkgs }:

let
  version = "0.9.5";
  src = applyPatches {
    src = fetchurl {
      url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
      sha256 = "0q8hfq4y7az5ly97brq1khhhvhnq6irzw0ginmz20fwn7w3yc5sn";
    };
    patches = [
      (fetchpatch {
        # https://github.com/JoinMarket-Org/joinmarket-clientserver/pull/1206
        name = "ob-export-fix";
        url = "https://patch-diff.githubusercontent.com/raw/JoinMarket-Org/joinmarket-clientserver/pull/1206.patch";
        sha256 = "0532gixjyc8r11sfmlf32v5iwy0rhkpa8rbvm4b7h509hnyycvhx";
      })
    ];
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

  meta = with lib; {
    description = "Bitcoin CoinJoin implementation";
    homepage = "https://github.com/JoinMarket-Org/joinmarket-clientserver";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = platforms.unix;
  };
}
