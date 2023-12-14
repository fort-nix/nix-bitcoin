{ buildPythonPackageWithDepsCheck
, clightning
, poetry-core
, pytestCheckHook
, bitstring
, cryptography
, coincurve
, base58
, pysocks
}:

buildPythonPackageWithDepsCheck rec {
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
    pysocks
  ];

  checkInputs = [ pytestCheckHook ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-proto";
}
