let
  pkgs = import <nixpkgs> {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  ciPkgs = with nbPkgs; [
    electrs
    elementsd
    hwi
    joinmarket
    lightning-charge
    lightning-loop
    nanopos
  ];
in
pkgs.writeText "ci-pkgs" (pkgs.lib.concatMapStringsSep "\n" toString ciPkgs)
