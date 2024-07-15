{ lib, buildPythonPackage, fetchFromGitHub, secp256k1 }:

buildPythonPackage rec {
  pname = "python-bitcointx";
  version = "1.1.5";

  src = fetchFromGitHub {
    owner = "Simplexum";
    repo = "python-bitcointx";
    rev = "python-bitcointx-v${version}";
    hash = "sha256-KXndYEsJ8JRTiGojrKXmAEeGDlHrNGs5MtYs9XYiqMo=";
  };

  patchPhase = ''
    for path in core/secp256k1.py tests/test_load_secp256k1.py; do
      substituteInPlace "bitcointx/$path" \
        --replace-fail "ctypes.util.find_library('secp256k1')" "'${secp256k1}/lib/libsecp256k1.so'"
    done
  '';

  pythonImportCheck = [
    "bitcointx"
  ];

  meta = with lib; {
    description = "Interface to Bitcoin transaction data structures";
    homepage = "https://github.com/Simplexum/python-bitcointx";
    maintainers = with maintainers; [ seberm nixbitcoin ];
    license = licenses.gpl3;
  };
}
