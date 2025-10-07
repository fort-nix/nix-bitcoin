{ buildPythonPackage
, clightning
, hatchling
, pytestCheckHook
, bitstring
, cryptography
, coincurve
, base58
, pysocks
}:

buildPythonPackage rec {
  pname = "pyln-proto";
  version = clightning.version;
  format = "pyproject";

  inherit (clightning) src;

  nativeBuildInputs = [ hatchling ];

  propagatedBuildInputs = [
    bitstring
    cryptography
    coincurve
    base58
    pysocks
  ];

  checkInputs = [ pytestCheckHook ];

  pythonNamespaces = [ "pyln" ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-proto";
}
