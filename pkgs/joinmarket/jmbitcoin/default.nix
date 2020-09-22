{ version, src, lib, buildPythonPackage, fetchurl, future, coincurve, urldecode, pyaes, python-bitcointx, secp256k1, joinmarketbase }:

buildPythonPackage rec {
  pname = "joinmarketbitcoin";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbitcoin";

  propagatedBuildInputs = [ future coincurve urldecode pyaes python-bitcointx secp256k1 ];

  checkInputs = [ joinmarketbase ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
