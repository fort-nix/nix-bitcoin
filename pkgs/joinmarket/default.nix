{ stdenv, lib, fetchurl, python3, nbPython3Packages, pkgs }:

let
  version = "0.8.0-a5e8879";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/a5e8879d119c8702476da32957d2cfecc3584c89.tar.gz";
    sha256 = "1l98mjk5rc5kji4yads6iicvyps0blsddwzclsiv0ha1az6dzpci";
  };

  runtimePackages = with nbPython3Packages; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
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
  '';
}
