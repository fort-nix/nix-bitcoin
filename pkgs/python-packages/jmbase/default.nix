{ version, src, lib, buildPythonPackageWithDepsCheck, fetchurl, future, twisted, service-identity, chromalog, txtorcon, pyaes }:

buildPythonPackageWithDepsCheck rec {
  pname = "joinmarketbase";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbase";

  propagatedBuildInputs = [ future twisted service-identity chromalog txtorcon pyaes ];

  patchPhase = ''
    sed -i 's|twisted==22.4.0|twisted==23.8.0|' setup.py
    sed -i 's|service-identity==21.1.0|service-identity==23.1.0|' setup.py
  '';

  # Has no tests
  doCheck = false;

  pythonImportsCheck = [
    "jmbase"
  ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
