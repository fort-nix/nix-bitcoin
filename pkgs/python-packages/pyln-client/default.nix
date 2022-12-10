{ buildPythonPackage, poetry-core, pytestCheckHook, clightning, pyln-bolt7, pyln-proto }:

buildPythonPackage rec {
  pname = "pyln-client";
  version = clightning.version;
  format = "pyproject";

  inherit (clightning) src;

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [
    pyln-bolt7
    pyln-proto
  ];

  checkInputs = [ pytestCheckHook ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";
}
