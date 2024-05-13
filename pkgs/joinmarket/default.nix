{ stdenv, lib, fetchFromGitHub, python3, nbPython3PackagesJoinmarket }:

let
  version = "0.9.11";
  src = fetchFromGitHub {
    owner = "joinmarket-org";
    repo = "joinmarket-clientserver";
    rev = "v${version}";
    hash = "sha256-sYHhhp9BZz8udJuVAfwdt474OQPiye2ae5DOn5v5yEQ=";
  };

  runtimePackages = with nbPython3PackagesJoinmarket; [
    joinmarket
    matplotlib # for ob-watcher
  ];

  pythonEnv = python3.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src;

  buildInputs = [ pythonEnv ];

  installPhase = ''
    mkdir -p "$out/bin"

    # add-utxo.py -> bin/jm-add-utxo
    cpBin() {
      cp "scripts/$1" "$out/bin/jm-''${1%.py}"
    }

    cp scripts/joinmarketd.py "$out/bin/joinmarketd"
    cpBin add-utxo.py
    cpBin receive-payjoin.py
    cpBin sendpayment.py
    cpBin sendtomany.py
    cpBin tumbler.py
    cpBin wallet-tool.py
    cpBin yg-privacyenhanced.py
    cpBin genwallet.py
    cpBin bond-calculator.py
    cpBin jmwalletd.py

    chmod +x -R "$out/bin"
    patchShebangs "$out/bin"

    ## ob-watcher
    obw=$out/libexec/joinmarket-ob-watcher
    install -D scripts/obwatch/ob-watcher.py "$obw/ob-watcher"
    patchShebangs "$obw/ob-watcher"
    ln -s "$obw/ob-watcher" "$out/bin/jm-ob-watcher"

    # These files must be placed in the same dir as ob-watcher
    cp -r scripts/obwatch/{orderbook.html,sybil_attack_calculations.py,vendor} "$obw"
  '';

  meta = with lib; {
    description = "Bitcoin CoinJoin implementation";
    homepage = "https://github.com/JoinMarket-Org/joinmarket-clientserver";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ seberm nixbitcoin ];
    platforms = platforms.unix;
  };
}
