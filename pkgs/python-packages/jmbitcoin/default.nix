{ version, src, lib, buildPythonPackageWithDepsCheck, fetchurl, python-bitcointx, joinmarketbase, pytestCheckHook }:

buildPythonPackageWithDepsCheck rec {
  pname = "joinmarketbitcoin";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbitcoin";

  propagatedBuildInputs = [ python-bitcointx ];

  checkInputs = [ joinmarketbase ];

  nativeCheckInputs = [
    pytestCheckHook
  ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
