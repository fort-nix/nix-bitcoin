{ pkgs }:
let
  nodePackages = import ./composition.nix { inherit pkgs; };
in
nodePackages.package.override {
  # Required because spark-wallet uses `npm-shrinkwrap.json` as the lock file
  reconstructLock = true;
}
