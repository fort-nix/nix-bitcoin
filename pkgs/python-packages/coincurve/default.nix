{ lib, stdenv, buildPythonPackage, fetchPypi, asn1crypto, cffi, pkg-config,
autoconf, automake, libtool, libffi, requests }:

buildPythonPackage rec {
  pname = "coincurve";
  version = "15.0.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0ras7qb4ib9sik703fcb9f3jrgq7nx5wvdgx9k1pshmrxl8lnlh6";
  };

  doCheck = false;
  nativeBuildInputs = [ autoconf automake libtool pkg-config ];
  propagatedBuildInputs = [ asn1crypto cffi libffi requests ];

  meta = with lib; {
    description = "Cross-platform Python CFFI bindings for libsecp256k1";
    homepage = "https://github.com/ofek/coincurve";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.asl20;
  };
}
