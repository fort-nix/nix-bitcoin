{ pkgs }:
let
  nodePackages = import ./composition.nix { inherit pkgs; inherit (pkgs) nodejs; };
in
nodePackages.package
