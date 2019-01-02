{pkgs, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-8_x"}:


with pkgs;
let
 d1 = stdenv.mkDerivation {
    name = "spark-wallet-sources";
    src = fetchurl {
      url = "https://registry.npmjs.org/spark-wallet/-/spark-wallet-0.2.0-rc.3.tgz";
      sha256 = "991855f6c103c3e2abfd6421597db31948bc3fb967d9066f0d804a88c22390fd";
    };

    buildInputs = [ nodePackages.node2nix git ];

    unpackPhase = ''
      mkdir -p $out
      tar -xzf $src -C $out
    '';

    installPhase = ''
      mkdir -p $out
      cd $out/package
      ${nodePackages.node2nix}/bin/node2nix -8 package.json
    '';
  };
  # import from derivation (IFD)
  packages = import (d1 + "/package/default.nix") {
    inherit pkgs system;
  };
in
packages
