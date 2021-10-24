let
  pinned = import ../pkgs/nixpkgs-pinned.nix;
  pkgs = import pinned.nixpkgs-unstable {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  pkgsUnstable = with nbPkgs; [
    # Disabled because joinmarket dependencies currently don't build on on unstable.
    # joinmarket
  ];
in
pkgs.writeText "pkgs-unstable" (pkgs.lib.concatMapStringsSep "\n" toString pkgsUnstable)
