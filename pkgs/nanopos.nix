{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-8_x"}:


with pkgs;
let
 d1 = stdenv.mkDerivation {
    name = "nanotip-sources";
    src = fetchurl {
      url = "https://registry.npmjs.org/nanopos/-/nanopos-0.1.3.tgz";
      sha256 = "602d250190d4991b288ed7c493226bcbf03e73181f5d4d54d34334404fc06bb6";
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
