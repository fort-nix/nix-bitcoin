pkgs:
let
  pythonTesting = import (pkgs.path + "/nixos/lib/testing-python.nix") {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
  };
in

module:
let
  test = (pythonTesting.evalTest module).config;

  runTest = pkgs.stdenv.mkDerivation {
    name = "vm-test-run-${test.name}";

    requiredSystemFeatures = [ "kvm" "nixos-test" ];

    # 1. Save test logging output
    # 2. Add link to driver so that a gcroot to a test prevents the driver from
    #    being garbage-collected
    buildCommand = ''
      mkdir "$out"
      LOGFILE=$out/output.xml tests='exec(os.environ["testScript"])' ${test.driver}/bin/nixos-test-driver
      ln -s ${test.driver} "$out/driver"
    '';

    inherit (test) meta passthru;
  } // test;
in
  runTest // {
    # A VM runner for interactive use
    run = pkgs.writers.writeBashBin "run-vm" ''
      . ${./run-vm.sh} ${runTest.driver} "$@"
    '';
  }
