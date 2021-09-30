{ lib
, buildPythonPackage
, fetchPypi
, pythonOlder
, cryptography
, bitcoinlib
, ecpy
, tox

}:

buildPythonPackage rec {
  pname = "squeakpy";
  version = "0.7.7";
  format = "setuptools";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "c9334fcc5c29e683ec99a98caba145b75157ae22a386e94f2162a533b8c11652";
  };

  propagatedBuildInputs = [
    cryptography
    bitcoinlib
    ecpy
  ];

  pythonImportsCheck = [
    "squeak"
  ];

  checkInputs = [
    tox
  ];

  meta = with lib; {
    homepage = "https://github.com/yzernik/squeak";
    description = "Common library for squeak protocol";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
