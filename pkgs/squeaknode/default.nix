{ lib
, buildPythonPackage
, fetchurl
, nbPython3Packages

}:

buildPythonPackage rec {
  pname = "squeaknode";
  version = "0.1.157";

  propagatedBuildInputs = with nbPython3Packages; [
    alembic
    expiringdict
    flask
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

  checkInputs = with nbPython3Packages; [
    tox
  ];
}

