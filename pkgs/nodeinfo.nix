with import <nixpkgs> {}; # bring all of Nixpkgs into scope

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
