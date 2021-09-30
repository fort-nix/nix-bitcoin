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
    urls = [ "https://github.com/yzernik/squeaknode/archive/refs/tags/v${version}.tar.gz" ];
    sha256 = "a179cca7101291ae078a185929fceb1a9954f57aeea2e3ffaaf687396bdb3ea6";
  };

  checkInputs = with nbPython3Packages; [
    tox
  ];
}

