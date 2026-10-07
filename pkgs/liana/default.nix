{ stdenv, lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "liana";
  version = "5.0";

  src = fetchFromGitHub {
    owner = "wizardsardine";
    repo = pname;
    rev = version;
    hash = "sha256-RkZ2HSN7IjwN3tD0UhpMeQeqkb+Y79kSWnjJZ5KPbQk=";
  };

  cargoHash = "sha256-v3tMz93mNsTy0k27IzgYk9bL2VfqtXImMlnvwgswp6U=";

  meta = {
    description = "The missing safety net for your coins";
    homepage = "https://wizardsardine.com/liana/";
    license = lib.licenses.bsd3;
  };

}