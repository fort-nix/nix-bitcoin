pkgs:
let
  makeVM = import ./make-test-vm.nix pkgs;
  inherit (pkgs) lib;
in

name: testConfig:
{
  vm = makeVM {
    name = "nix-bitcoin-${name}";

    machine = {
      imports = [ testConfig ];
      virtualisation = {
        # Needed because duplicity requires 270 MB of free temp space, regardless of backup size
        diskSize = 1024;

        # Min. 800 MiB needed to avoid 'out of memory' errors
        memorySize = lib.mkDefault 2048;

        cores = lib.mkDefault 2;
      };
    };

    testScript = nodes: let
      cfg = nodes.nodes.machine.config;
      data = {
        data = cfg.test.data;
        tests = cfg.tests;
      };
      dataFile = pkgs.writeText "test-data" (builtins.toJSON data);
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
    containers.nb-test = { config, ... }: {
      config = {
        extra = config.config.test.container;
        config = testConfig;
      };
    };
  };

  # This allows running a test scenario in a regular NixOS VM.
  # No tests are executed.
  vmWithoutTests = (pkgs.nixos {
    imports = [
      testConfig
      "${toString pkgs.path}/nixos/modules/virtualisation/qemu-vm.nix"
    ];
    virtualisation.graphics = false;
    services.getty.autologinUser = "root";

    # Provide a shortcut for instant poweroff from within the machine
    environment.systemPackages = with pkgs; [
      (lowPrio (writeScriptBin "q" ''
         echo o >/proc/sysrq-trigger
       ''))
    ];
  }).vm;

  config = testConfig;
}
