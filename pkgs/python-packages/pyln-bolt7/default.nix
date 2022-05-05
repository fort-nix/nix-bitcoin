{ buildPythonPackage, poetry-core, pytestCheckHook, clightning, pyln-proto }:

buildPythonPackage rec {
  pname = "pyln-bolt7";
  # The version is defined here:
  # https://github.com/ElementsProject/lightning/blob/master/contrib/pyln-spec/bolt7/pyproject.toml
  version = "1.0.2.186.post0";
  format = "pyproject";

  inherit (clightning) src;

  nativeBuildInputs = [ poetry-core ];
  propagatedBuildInputs = [ pyln-proto ];
  checkInputs = [ pytestCheckHook ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-spec/bolt7";
}
