{pkgs}:

with pkgs;
stdenv.mkDerivation {
  name = "nodeinfo";
  src = ./nodeinfo.sh;

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out
    mkdir -p $out/bin
    cp $src $out/bin/nodeinfo
    chmod +x $out/bin/nodeinfo
    '';
}
