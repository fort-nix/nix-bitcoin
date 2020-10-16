scenario: testConfig:

{
  vm = import ./make-test-vm.nix {
    name = "nix-bitcoin-${scenario}";

    machine = {
      imports = [ testConfig ];
      # Needed because duplicity requires 270 MB of free temp space, regardless of backup size
      virtualisation.diskSize = 1024;
    };

    testScript = nodes: let
      cfg = nodes.nodes.machine.config;
      data = {
        data = cfg.test.data;
        tests = cfg.tests;
      };
      dataFile = builtins.toFile "test-data" (builtins.toJSON data);
      initData = ''
        import json

        with open("${dataFile}") as f:
            data = json.load(f)

        enabled_tests = set(test for (test, enabled) in data["tests"].items() if enabled)
        test_data = data["data"]
      '';
    in
      builtins.concatStringsSep "\n\n" [
        initData
        (builtins.readFile ./../tests.py)
        # Don't run tests in interactive mode.
        # is_interactive is set in ../run-tests.sh
        ''
          if not "is_interactive" in vars():
              run_tests()
        ''
      ];
  };

  container = {
    # The container name has a 11 char length limit
    containers.nb-test = { config, ...}: {
      config = {
        extra = config.config.test.container;
        config = testConfig;
      };
    };
  };
}
