{ lib
, buildPythonPackage
, fetchPypi
, pyzmq
, setuptools
, twisted
}:

buildPythonPackage rec {
  pname = "txzmq";
  version = "0.8.2";

  src = fetchPypi {
    pname = "txZMQ";
    inherit version;
    sha256 = "07a9a480e58d4d732eef9efd7e264f2348cbf27ee82b338ec818a8504006e1c0";
  };

  propagatedBuildInputs = [
    pyzmq
    setuptools
    twisted
  ];

  meta = with lib; {
    description = "Twisted bindings for ZeroMQ";
    homepage = "https://github.com/smira/txZMQ";
    license = licenses.gpl2;
  };
}
