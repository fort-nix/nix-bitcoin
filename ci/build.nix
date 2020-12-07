let
  pkgs = import <nixpkgs> {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  ciPkgs = with nbPkgs; [
    electrs
    elementsd
    hwi
    joinmarket
    lightning-loop
  ];
in
pkgs.writeText "ci-pkgs" (pkgs.lib.concatMapStringsSep "\n" toString ciPkgs)
