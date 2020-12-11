let
  pinned = import ../pkgs/nixpkgs-pinned.nix;
  pkgs = import pinned.nixpkgs-unstable {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  pkgsUnstable = with nbPkgs; [
    electrs
    elementsd
    hwi
    joinmarket
    lightning-loop
  ];
in
pkgs.writeText "pkgs-unstable" (pkgs.lib.concatMapStringsSep "\n" toString pkgsUnstable)
