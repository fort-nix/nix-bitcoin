let
  pinned = import ../pkgs/nixpkgs-pinned.nix;
  pkgs = import pinned.nixpkgs-unstable {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  pkgsUnstable = with nbPkgs; [
    joinmarket
  ];
in
pkgs.writeText "pkgs-unstable" (pkgs.lib.concatMapStringsSep "\n" toString pkgsUnstable)
