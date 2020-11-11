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
       };
       test' = test (args // { pkgs = pkgsFixed; });
    in
      # See nixpkgs/nixos/lib/testing-python.nix for the original definition
      test'.overrideAttrs (_: {
        # 1. Save test output
        # 2. Add link to driver so that a gcroot to a test prevents the driver from
        #    being garbage-collected
        buildCommand = ''
          mkdir $out
          LOGFILE=$out/output.xml tests='exec(os.environ["testScript"])' ${test'.driver}/bin/nixos-test-driver
          ln -s ${test'.driver} $out/driver
        '';
      }) // { inherit (test') nodes driver; } ;

in
  fixedTest
