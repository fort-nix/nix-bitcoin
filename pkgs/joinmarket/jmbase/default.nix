{ version, src, lib, buildPythonPackage, fetchurl, future, twisted, service-identity, chromalog }:

buildPythonPackage rec {
  pname = "joinmarketbase";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbase";

  propagatedBuildInputs = [ future twisted service-identity chromalog ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
