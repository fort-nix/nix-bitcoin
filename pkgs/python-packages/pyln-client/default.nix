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

  # TODO-EXTERNAL:
  # This patch is a variant (fixed relative path) of
  # https://github.com/ElementsProject/lightning/pull/5574. This is already
  # fixed upstream. Remove this after the next clightning release.
  patches = [
    ./msat-null.patch
  ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";
}
