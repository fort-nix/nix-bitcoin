{ buildPythonPackage, clightning
, bitstring
, cryptography
, coincurve
, base58
, mypy
}:

buildPythonPackage rec {
  pname = "pyln-proto";
  version = "0.10.1"; # defined in ${src}/contrib/pyln-proto/setup.py

  inherit (clightning) src;

  propagatedBuildInputs = [
    bitstring
    cryptography
    coincurve
    base58
    mypy
  ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";

}
