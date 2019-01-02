{pkgs}:

with pkgs;
stdenv.mkDerivation {
  name = "nodeinfo";
  src = ./nodeinfo.sh;

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out
    mkdir -p $out/bin
    chmod +wx $src
    cp $src $out/bin/nodeinfo
    '';
}
