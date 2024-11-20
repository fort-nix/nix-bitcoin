{ stdenv, pkgs, lib, fetchFromGitHub, ... }:

stdenv.mkDerivation rec {
  name = "asmap-data";
  version = "dcce69e48211facdbd52a461cfce333d5800b7de";

  src = pkgs.fetchFromGitHub {
    owner = "asmap";
    repo = "asmap-data";
    rev = version;
    sha256 = "sha256-bp93VZX6EF6vwpbA4jqAje/1txfKeqN9BhVRLkdM+94=";
  };

  installPhase = ''
    cp -r $src/latest_asmap.dat $out
  '';

  meta = {
    description = "Contains an asmap file from the ASMap Data Demo Repository";
    homepage = "https://github.com/asmap/asmap-data";
    license = lib.licenses.mit;
  };
}
