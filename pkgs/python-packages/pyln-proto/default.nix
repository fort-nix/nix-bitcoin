{ buildPythonPackage
, clightning
, poetry-core
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

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'coincurve = "^18"' 'coincurve = "^19"' \
      --replace-fail 'cryptography = "^41"' 'cryptography = "^42"' \
  '';
}
