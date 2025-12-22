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

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'coincurve==20.0.0' 'coincurve==21.0.0'
  '';

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
