{ buildPythonPackage
, clightning
, poetry-core
, pytestCheckHook
, bitstring
, cryptography
, coincurve
, base58
}:

buildPythonPackage rec {
  pname = "pyln-proto";
  version = clightning.version;
  format = "pyproject";

  inherit (clightning) src;

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [
    bitstring
    cryptography
    coincurve
    base58
  ];

  checkInputs = [ pytestCheckHook ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-proto";
}
