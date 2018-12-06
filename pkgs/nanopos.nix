{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-8_x"}:


with pkgs;
let
 d1 = stdenv.mkDerivation {
    name = "nanopos-sources";
    src = fetchurl {
      url = "https://registry.npmjs.org/nanopos/-/nanopos-0.1.4.tgz";
      sha256 = "294c4ac90027e5172408dadad9a62e0117459e4c60d4ab362b12190887c698ec";
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
