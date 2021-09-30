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
    sha256 = "30a790e490bbb101da9a6fb3f917f5baceb8c5919635bdec31c9d70c96a8449c";
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
