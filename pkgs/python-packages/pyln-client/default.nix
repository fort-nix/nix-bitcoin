{ buildPythonPackage, hatchling, pytestCheckHook, clightning, pyln-bolt7, pyln-proto }:

buildPythonPackage rec {
  pname = "pyln-client";
  version = clightning.version;
  format = "pyproject";

  inherit (clightning) src;

  nativeBuildInputs = [ hatchling ];

  propagatedBuildInputs = [
    pyln-bolt7
    pyln-proto
  ];

  checkInputs = [ pytestCheckHook ];

  pythonNamespaces = [ "pyln" ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";
}
