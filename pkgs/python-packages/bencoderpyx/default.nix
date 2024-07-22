{ lib, buildPythonPackage, fetchurl, cython, pytest, coverage }:

buildPythonPackage rec {
  pname = "bencoder.pyx";
  version = "3.0.1";

  src = fetchurl {
    url = "https://github.com/whtsky/bencoder.pyx/archive/9a47768f3ceba9df9e6fbaa7c445f59960889009.tar.gz";
    sha256 = "1yh565xjbbhn49xjfms80ac8psjbzn66n8dcx0x8mn7zzjv06clz";
  };

  nativeBuildInputs = [ cython ];

  checkInputs = [ pytest coverage ];

  meta = with lib; {
    description = "A fast bencode implementation in Cython";
    homepage = "https://github.com/whtsky/bencoder.pyx";
    maintainers = with maintainers; [ seberm nixbitcoin ];
    license = licenses.bsd3;
  };
}
