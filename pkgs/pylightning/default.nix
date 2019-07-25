{ lib, buildPythonPackage, fetchPypi }:

buildPythonPackage rec {
  pname = "pylightning";
  version = "0.0.7";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0anbixqsfk0dsm790yy21f403lwgalxaqlm1s101ifppmxqccgpi";
  };

  doCheck = false;
}
