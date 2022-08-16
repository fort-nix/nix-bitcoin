pkgs:
let
  pythonTesting = import "${toString pkgs.path}/nixos/lib/testing-python.nix" {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
  };
in

args:
let
  test = pythonTesting.makeTest args;

  # 1. Save test logging output
  # 2. Add link to driver so that a gcroot to a test prevents the driver from
  #    being garbage-collected
  fixedTest = test.overrideAttrs (_: {
    # See `runTests` in nixpkgs/nixos/lib/testing-python.nix for the original definition of `buildCommand`
    buildCommand = ''
      mkdir "$out"
      LOGFILE=$out/output.xml tests='exec(os.environ["testScript"])' ${test.driver}/bin/nixos-test-driver
      ln -s ${test.driver} "$out/driver"
    '';
  });
in
  fixedTest
