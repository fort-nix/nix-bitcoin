{ buildPythonPackage, hatchling, pytestCheckHook, clightning, pyln-proto }:

buildPythonPackage rec {
  pname = "pyln-bolt7";
  # The version is defined here:
  # https://github.com/ElementsProject/lightning/blob/master/contrib/pyln-spec/bolt7/pyproject.toml
  version = "1.0.4.246";
  format = "pyproject";

  inherit (clightning) src;

  nativeBuildInputs = [ hatchling ];
  propagatedBuildInputs = [ pyln-proto ];
  checkInputs = [ pytestCheckHook ];

  pythonNamespaces = [ "pyln" ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-spec/bolt7";
}
