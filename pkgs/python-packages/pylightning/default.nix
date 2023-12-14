{ buildPythonPackageWithDepsCheck, clightning, pyln-client }:

buildPythonPackageWithDepsCheck rec {
  pname = "pylightning";
  version = "0.10.1"; # defined in ${src}/contrib/pyln-client/pyln/client/__init__.py

  inherit (clightning) src;

  propagatedBuildInputs = [ pyln-client ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";

}
