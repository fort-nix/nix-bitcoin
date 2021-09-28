{ lib
, buildPythonPackage
, fetchurl
, alembic
, expiringdict
, flask
, flask-cors
, flask-login
, flask-wtf
, googleapis-common-protos
, grpcio
, grpcio-tools
, importlib-resources
, mypy-protobuf
, protobuf
, psycopg2
, pysocks
, bitcoinlib
, pyzmq
, requests
, sqlalchemy
, ecpy
, cryptography

}:

buildPythonPackage rec {
  pname = "squeaknode";
  version = "0.1.156";

  propagatedBuildInputs = [ click ];

  src = fetchurl {
    urls = [ "https://github.com/Blockstream/liquid-swap/archive/release_${version}.tar.gz" ];
    sha256 = "9fa920ee7d03d1af8252131cd7d5a825bb66b8ad536403b4f5437ff6c91a68b1";
  };
  # Not sure if this does anything, but it should
  installFlags = [ ".[CLI]" ];
  # The tests unfortunately seem to require the PyQt for the GUI
  doCheck = false;
}

