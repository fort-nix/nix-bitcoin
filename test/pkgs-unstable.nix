let
  pinned = import ../pkgs/nixpkgs-pinned.nix;
  pkgs = import pinned.nixpkgs-unstable {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  pkgsUnstable = with nbPkgs; [
    joinmarket

    ## elementsd fails with error
    # test/key_properties.cpp:16:10: fatal error: rapidcheck/boost_test.h: No such file or directory
    # 16 | #include <rapidcheck/boost_test.h>
    #    |          ^~~~~~~~~~~~~~~~~~~~~~~~~
    # elementsd
  ];
in
pkgs.writeText "pkgs-unstable" (pkgs.lib.concatMapStringsSep "\n" toString pkgsUnstable)
