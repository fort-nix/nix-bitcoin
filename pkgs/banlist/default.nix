{pkgs}:

with pkgs;
stdenv.mkDerivation {
  name = "banlist";
  src = ./banlist.sh;

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out
    mkdir -p $out/bin
    cp $src $out/bin/banlist
    chmod +x $out/bin/banlist
    '';
}
