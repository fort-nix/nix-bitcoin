{ buildPythonPackage, clightning
, bitstring
, cryptography
, coincurve
, base58
, mypy
}:

buildPythonPackage rec {
  pname = "pyln-proto";
  version = "0.8.4"; # defined in ${src}/contrib/pyln-proto/setup.py

  inherit (clightning) src;

  propagatedBuildInputs = [
    bitstring
    cryptography
    coincurve
    base58
    mypy
  ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";

  postPatch = ''
    substituteInPlace requirements.txt \
      --replace base58==1.0.2 base58==2.0.1 \
      --replace bitstring==3.1.6 bitstring==3.1.5 \
      --replace cryptography==2.8 cryptography==3.1
  '';
}
