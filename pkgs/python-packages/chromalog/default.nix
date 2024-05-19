{ lib, buildPythonPackageWithDepsCheck, fetchFromGitHub, colorama, future, six }:
buildPythonPackageWithDepsCheck rec {
  pname = "chromalog";
  version = "1.0.5";

  src = fetchFromGitHub {
    owner = "freelan-developers";
    repo = "chromalog";
    rev = version;
    sha256 = "0pj4s52rgwlvwkzrj85y92c5r9c84pz8gga45jl5spysrv41y9p0";
  };

  propagatedBuildInputs = [ colorama future six ];

  # enable when https://github.com/freelan-developers/chromalog/issues/6 is resolved
  doCheck = false;

  meta = with lib; {
    description = "Enhance Python with colored logging";
    homepage = "https://github.com/freelan-developers/chromalog";
    maintainers = with maintainers; [ seberm nixbitcoin ];
    license = licenses.mit;
  };
}
