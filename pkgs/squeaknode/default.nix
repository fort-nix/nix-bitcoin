{ lib, buildPythonPackage, fetchurl, alembic, expiringdict, flask, flask-cors, flask-login, flask-wtf, googleapis-common-protos, grpcio, grpcio-tools, importlib-resources, mypy-protobuf, protobuf, psycopg2, pysocks, bitcoinlib, pyzmq, requests, sqlalchemy, ecpy, cryptography, squeakpy, typed-config, tox }:

buildPythonPackage rec {
  pname = "squeaknode";
  version = "0.1.157";

  propagatedBuildInputs = [
    alembic
    expiringdict
    flask
    flask-cors
    flask-login
    flask-wtf
    googleapis-common-protos
    grpcio
    grpcio-tools
    importlib-resources
    mypy-protobuf
    protobuf
    psycopg2
    pysocks
    bitcoinlib
    pyzmq
    requests
    sqlalchemy
    squeakpy
    typed-config
  ];

  src = fetchurl {
    urls = [ "https://github.com/yzernik/squeaknode/archive/release_${version}.tar.gz" ];
    sha256 = "TODO";
  };

  checkInputs = [
    tox
  ];
}

