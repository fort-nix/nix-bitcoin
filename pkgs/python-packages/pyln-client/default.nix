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

  # Fix version typo in pyproject.toml
  # TODO-EXTERNAL:
  # This is already fixed upstream. Remove this after the next clightning release.
  postPatch = ''
    sed -i 's|pyln-bolt7 = "^1.0.186"|pyln-bolt7 = "^1.0.2.186"|' pyproject.toml
  '';
}
