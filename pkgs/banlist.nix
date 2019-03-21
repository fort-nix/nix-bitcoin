{pkgs}:

with pkgs;
stdenv.mkDerivation {
  name = "banlist";
  src = ./banlist.sh;

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out
    mkdir -p $out/bin
    chmod +wx $src
    cp $src $out/bin/banlist
    '';
}
