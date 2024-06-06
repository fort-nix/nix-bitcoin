{ buildPythonPackageWithDepsCheck, poetry-core, pytestCheckHook, clightning, pyln-bolt7, pyln-proto }:

buildPythonPackageWithDepsCheck rec {
  pname = "pyln-client";
  inherit (clightning) src version;
  format = "pyproject";

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [
    pyln-bolt7
    pyln-proto
  ];

  checkInputs = [ pytestCheckHook ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";
}
