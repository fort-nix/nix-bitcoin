{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, python3
}:

stdenvNoCC.mkDerivation rec {
  pname = "utxoracle";
  version = "9.1";

  src = fetchurl {
    url = "https://utxo.live/oracle/UTXOracle.py";
    hash = "sha256-m20z+clE3L4oV4R9NAqYSg7p85qR9cwu8XODkmpqAsU=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm444 "$src" "$out/share/utxoracle/UTXOracle.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/utxoracle" \
      --add-flags "$out/share/utxoracle/UTXOracle.py"

    runHook postInstall
  '';

  meta = {
    description = "Local confirmed-block Bitcoin price estimator";
    homepage = "https://utxo.live/oracle/";
    mainProgram = "utxoracle";
    license = {
      fullName = "UTXOracle License 1.0";
      url = "https://utxo.live/oracle/license.php";
      free = false;
      redistributable = true;
    };
    maintainers = with lib.maintainers; [ nixbitcoin ];
    platforms = lib.platforms.unix;
  };
}
