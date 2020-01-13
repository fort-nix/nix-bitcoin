testArgs:

let
  pkgs = import <nixpkgs> { config = {}; overlays = []; };

  # Stable nixpkgs doesn't yet include the Python testing framework.
  # Use unstable nixpkgs and patch it so that it uses stable nixpkgs for the VM
  # machine configuration.
  testingPkgs = let
    # unstable as of 2020-01-09
    rev = "9beb0d1ac2ebd6063efbdc4d3631f8ce137bbf90";
    src = builtins.fetchTarball {
        url = "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
        sha256 = "1v95779di35qhrz70p2v27kmwm09h8pgh74i1wc72v0zp3bdrf50";
    };
  in
    pkgs.runCommand "nixpkgs-testing" {} ''
    cp -r ${src} $out
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
