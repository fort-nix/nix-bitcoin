testArgs:

let
  pkgs = import <nixpkgs> { config = {}; overlays = []; };
  unstable = (import ../pkgs/nixpkgs-pinned.nix).nixpkgs-unstable;

  # Stable nixpkgs doesn't yet include the Python testing framework.
  # Use unstable nixpkgs and patch it so that it uses stable nixpkgs for the VM
  # machine configuration.
  testingPkgs =
    pkgs.runCommand "nixpkgs-testing" {} ''
    cp -r ${unstable} $out
    cd $out
    chmod +w -R .
    patch -p1 < ${./use-stable-pkgs.patch}
  '';

  test = (import "${testingPkgs}/nixos/tests/make-test-python.nix") testArgs;

  # Fix the black Python code formatter that's used in the test to allow the test
  # script to have longer lines. The default width of 88 chars is too restrictive for
  # our script.
  fixedTest = { system ? builtins.currentSystem, ... }@args:
    let
       pkgs = (import testingPkgs { inherit system; config = {}; overlays = []; } );
       pkgsFixed = pkgs // {
         python3Packages = pkgs.python3Packages // {
           black = pkgs.writeScriptBin "black" ''
             fileToCheck=''${@:$#}
             [[ $fileToCheck = *test-script ]] && extraArgs='--line-length 100'
             exec ${pkgs.python3Packages.black}/bin/black $extraArgs "$@"
           '';
         };
       };
    in
      test (args // { pkgs = pkgsFixed; });
in
  fixedTest
