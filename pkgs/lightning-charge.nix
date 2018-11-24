{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-8_x"}:


with pkgs;
let
 d1 = stdenv.mkDerivation {
    name = "lightning-charge-sources";
    src = fetchurl {
      url = "https://registry.npmjs.org/lightning-charge/-/lightning-charge-0.4.4.tgz";
      sha256 = "4cd3c918664e99deca3317238856b3c12c314d4ab9f3a61540bee75f9bfed3d7";
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

      # terrible hack but I'm really exhausted
      sed -i "17iglobalBuildInputs = [ pkgs.nodePackages_8_x.node-pre-gyp ];" default.nix
    '';
  };
  # import from derivation (IFD)
  packages = import (d1 + "/package/default.nix") {
    inherit pkgs system;
  };
in
packages
