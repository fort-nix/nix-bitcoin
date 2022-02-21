{ sha256, lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage {
  pname = "runes";
  version = "0.4.0";

  src = fetchFromGitHub {
    repo = "runes";
    owner = "rustyrussell";
    rev = "7e3d7648db844ce2c78cc3e9e4f872f827252251";
    sha256 = "sha256-e0iGLV/57gCpqA7vrW6JMFM0R6iAq5oFwUpZoGySwfs=";
  };

  propagatedBuildInputs = [ sha256 ];

  meta = with lib; {
    description = "Runes for authentication (like macaroons only simpler)";
    homepage = "https://github.com/rustyrussell/runes";
    maintainers = with maintainers; [ jb55 ];
    license = licenses.mit;
  };
}
