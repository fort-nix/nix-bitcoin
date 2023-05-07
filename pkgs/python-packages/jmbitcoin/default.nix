{ version, src, lib, buildPythonPackage, fetchurl, pyaes, python-bitcointx, joinmarketbase }:

buildPythonPackage rec {
  pname = "joinmarketbitcoin";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbitcoin";

  propagatedBuildInputs = [ pyaes python-bitcointx ];

  checkInputs = [ joinmarketbase ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
