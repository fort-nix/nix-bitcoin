{ lib, buildPythonPackage, fetchurl, secp256k1, openssl }:

buildPythonPackage rec {
  pname = "python-bitcointx";
  version = "1.1.1";

  src = fetchurl {
    url = "https://github.com/Simplexum/${pname}/archive/${pname}-v${version}.tar.gz";
    sha256 = "35edd694473517508367338888633954eaa91b2622b3caada8fd3030ddcacba2";
  };

  patchPhase = ''
    for path in core/secp256k1.py tests/test_load_secp256k1.py; do
      substituteInPlace "bitcointx/$path" \
        --replace "ctypes.util.find_library('secp256k1')" "'${secp256k1}/lib/libsecp256k1.so'"
    done
    substituteInPlace bitcointx/core/key.py \
      --replace "ctypes.util.find_library('ssl')" "'${openssl.out}/lib/libssl.so'"
  '';

  meta = with lib; {
    description = "Interface to Bitcoin transaction data structures";
    homepage = "https://github.com/Simplexum/python-bitcointx";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
