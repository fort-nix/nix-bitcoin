{ stdenv, pkgs }:

stdenv.mkDerivation {
  name = "netns-exec";
  buildInputs = [ pkgs.libcap ];
  src = ./src;
  installPhase = ''
    cp main $out
  '';
}
