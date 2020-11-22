{ buildPythonPackage, clightning, recommonmark }:

buildPythonPackage rec {
  pname = "pyln-client";
  version = "0.8.0"; # defined in ${src}/contrib/pyln-client/pyln/client/__init__.py

  inherit (clightning) src;

  propagatedBuildInputs = [ recommonmark ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";
}
