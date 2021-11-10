{ buildPythonPackage, clightning, pyln-bolt7, recommonmark, setuptools-scm }:

buildPythonPackage rec {
  pname = "pyln-client";
  version = clightning.version;

  inherit (clightning) src;

  propagatedBuildInputs = [ pyln-bolt7 recommonmark setuptools-scm ];

  SETUPTOOLS_SCM_PRETEND_VERSION = version;

  postUnpack = "sourceRoot=$sourceRoot/contrib/${pname}";
}
