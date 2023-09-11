{ version, src, lib, buildPythonPackage, fetchurl, future, twisted, service-identity, chromalog, txtorcon }:

buildPythonPackage rec {
  pname = "joinmarketbase";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbase";

  patchPhase = ''
    sed -i 's|twisted==22.4.0|twisted==22.10.0|' setup.py
    sed -i 's|service-identity==21.1.0|service-identity==23.1.0|' setup.py
  '';

  propagatedBuildInputs = [ future twisted service-identity chromalog txtorcon ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
