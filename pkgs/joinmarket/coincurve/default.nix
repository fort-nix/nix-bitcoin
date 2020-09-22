{ lib, buildPythonPackage, fetchPypi, asn1crypto, cffi, pkg-config, libtool, libffi, requests, gmp }:

buildPythonPackage rec {
  pname = "coincurve";
  version = "13.0.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1x8dpbq6bwswfyi1g4r421hnswp904l435rf7n6fj7y8q1yn51cr";
  };

  nativeBuildInputs = [ pkg-config libtool libffi gmp ];

  propagatedBuildInputs = [ asn1crypto cffi requests ];

  # enable when https://github.com/ofek/coincurve/issues/47 is resolved
  doCheck = false;

  meta = with lib; {
    description = "Cross-platform Python CFFI bindings for libsecp256k1";
    homepage = "https://github.com/ofek/coincurve";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.asl20;
  };
}
