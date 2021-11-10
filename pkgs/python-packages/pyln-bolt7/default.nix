{ buildPythonPackage, clightning, pyln-proto }:

buildPythonPackage rec {
  pname = "pyln-bolt7";

  # See fn `bolt_meta` in
  # https://github.com/ElementsProject/lightning/blob/master/contrib/pyln-spec/bolt7/setup.py
  version = "1.0.2.186";

  inherit (clightning) src;

  propagatedBuildInputs = [ pyln-proto ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-spec/bolt7";

  # TODO-EXTERNAL
  # Remove when this fix is released
  # https://github.com/ElementsProject/lightning/pull/4910
  postPatch = ''
    sed -i 's|pyln.proto|pyln-proto|' requirements.txt
  '';
}
