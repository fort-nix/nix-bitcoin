testArgs:

let
  pkgs = import <nixpkgs> { config = {}; overlays = []; };

  test = (import "${pkgs.path}/nixos/tests/make-test-python.nix") testArgs;

  fixedTest = { system ? builtins.currentSystem, ... }@args:
    let
       pkgsFixed = pkgs // {
         # Fix the black Python code formatter that's used in the test to allow the test
         # script to have longer lines. The default width of 88 chars is too restrictive for
         # our script.
         python3Packages = pkgs.python3Packages // {
           black = pkgs.writeScriptBin "black" ''
             fileToCheck=''${@:$#}
             [[ $fileToCheck = *test-script ]] && extraArgs='--line-length 100'
             exec ${pkgs.python3Packages.black}/bin/black $extraArgs "$@"
           '';
         };

         # QEMU 4.20 from unstable fails on Travis build nodes with message
         # "error: failed to set MSR 0x48b to 0x159ff00000000"
         # Use version 4.0.1 instead.
         inherit (pkgs) qemu_test;
       };
    in
      test (args // { pkgs = pkgsFixed; });
in
  fixedTest
