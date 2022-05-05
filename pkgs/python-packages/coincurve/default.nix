{ lib, stdenv, buildPythonPackage, fetchPypi, asn1crypto, cffi, pkg-config,
autoconf, automake, libtool, libffi, requests }:

buildPythonPackage rec {
  pname = "coincurve";
  version = "17.0.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-aNpVr/iYcClS/aPuBP1u1gu2uR+RnGknB4btdmtUi5M";
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
