{ lib, buildPythonPackage, fetchurl, cython, pytest, coverage }:

buildPythonPackage rec {
  pname = "bencoder.pyx";
  version = "2.0.1";

  src = fetchurl {
    url = "https://github.com/whtsky/bencoder.pyx/archive/v${version}.tar.gz";
    sha256 = "f3ff92ac706a7e4692bed5e6cbe205963327f3076f55e408eb948659923eac72";
  };

  nativeBuildInputs = [ cython ];

  checkInputs = [ pytest coverage ];

  meta = with lib; {
    description = "A fast bencode implementation in Cython";
    homepage = "https://github.com/whtsky/bencoder.pyx";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.bsd3;
  };
}
