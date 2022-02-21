{ lib, buildPythonPackage, fetchFromGitHub, cython }:

buildPythonPackage rec {
  pname = "sha256";
  version = builtins.substring 0 8 src.rev;

  # The version from pypi is old/broken
  src = fetchFromGitHub {
    repo = "sha256";
    owner = "cloudtools";
    rev = "e0645d118f7296dde45397a755261f78d421bdee";
    sha256 = "sha256-gEctMgF5qZiWelVHVCl3zazRNuaQ7lJP8ExI5xWEBVI=";
  };

  nativeBuildInputs = [ cython ];

  doCheck = false;

  configurePhase = ''
    python setup.py sdist
  '';

  meta = with lib; {
    description = ''
      SHA-256 implementation that allows for setting and getting the mid-state
      information.
    '';
    homepage = "https://github.com/cloudtools/sha256";
    maintainers = with maintainers; [ jb55 ];
    license = licenses.mit;
  };
}
