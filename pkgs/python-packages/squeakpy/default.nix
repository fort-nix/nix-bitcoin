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
    sha256 = "TODO";
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
