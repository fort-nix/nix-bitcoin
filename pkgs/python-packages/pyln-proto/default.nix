{ buildPythonPackage, clightning
, bitstring
, cryptography
, coincurve
, base58
, mypy
, setuptools-scm
}:

buildPythonPackage rec {
  pname = "pyln-proto";
  version = clightning.version;

  inherit (clightning) src;

  propagatedBuildInputs = [
    bitstring
    cryptography
    coincurve
    base58
    mypy
    setuptools-scm
  ];

  SETUPTOOLS_SCM_PRETEND_VERSION = version;

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-proto";
  postPatch = ''
    sed -i '
      s|coincurve ~= 13.0|coincurve == 15.0.0|
      s|base58 ~= 2.0.1|base58 == 2.1.0|
      s|mypy==0.790|mypy == 0.812|
    ' requirements.txt
  '';
}
