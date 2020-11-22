{ buildPythonPackage, clightning, pyln-client }:

buildPythonPackage rec {
  pname = "pylightning";
  version = "0.8.0"; # defined in ${src}/contrib/pyln-client/pyln/client/__init__.py

  inherit (clightning) src;

  propagatedBuildInputs = [ pyln-client ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";

  # The clightning source contains pyln-client 0.8.0
  postPatch = ''
    substituteInPlace requirements.txt --replace pyln-client==0.7.3 pyln-client==0.8.0
  '';
}
