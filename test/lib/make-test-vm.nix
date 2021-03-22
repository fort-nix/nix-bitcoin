pkgs:
let
  pythonTesting = import "${toString pkgs.path}/nixos/lib/testing-python.nix" {
    system = builtins.currentSystem;
    inherit pkgs;
  };
in

args:
let
  test = pythonTesting.makeTest args;

  fixedDriver = test.driver.overrideAttrs (old: let
    # Allow the test script to have longer lines by fixing the call to the 'black'
    # code formatter.
    # The default width of 88 chars is too restrictive for our script.
    parts = builtins.split ''/nix/store/[^ ]+/black '' old.buildCommand;
    preMatch = builtins.elemAt parts 0;
    postMatch = builtins.elemAt parts 2;
  in {
    # See `mkDriver` in nixpkgs/nixos/lib/testing-python.nix for the original definition of `buildCommand`
    buildCommand = ''
      ${preMatch}${pkgs.python3Packages.black}/bin/black --line-length 100 ${postMatch}
    '';
    # Keep reference to the `testDriver` derivation, required by `buildCommand`
    testDriverReference = old.buildCommand;
  });

  # 1. Use fixed driver
  # 2. Save test logging output
  # 3. Add link to driver so that a gcroot to a test prevents the driver from
  #    being garbage-collected
  fixedTest = test.overrideAttrs (_: {
    # See `runTests` in nixpkgs/nixos/lib/testing-python.nix for the original definition of `buildCommand`
    buildCommand = ''
      mkdir $out
      LOGFILE=$out/output.xml tests='exec(os.environ["testScript"])' ${fixedDriver}/bin/nixos-test-driver
      ln -s ${fixedDriver} $out/driver
    '';
  }) // {
    driver = fixedDriver;
    inherit (test) nodes;
  };
in
  fixedTest
