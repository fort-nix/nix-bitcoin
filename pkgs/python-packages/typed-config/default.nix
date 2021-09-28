{ lib
, buildPythonPackage
, fetchPypi
, pythonOlder
, pytest

}:

buildPythonPackage rec {
  pname = "typed-config";
  version = "0.2.5";
  format = "setuptools";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "TODO";
  };

  pythonImportsCheck = [
    "typedconfig"
  ];

  checkInputs = [
    pytest
  ];

  meta = with lib; {
    homepage = "https://github.com/bwindsor/typed-config";
    description = "Typed, extensible, dependency free configuration reader.";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
