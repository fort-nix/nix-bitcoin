flake: pkgs: makeTestVM:
let
  inherit (flake.inputs) extra-container;
  inherit (pkgs.stdenv.hostPlatform) system;
in

{ name ? "nix-bitcoin-test", config }:
let
  inherit (pkgs) lib;

  testConfig = config;

  test = makeTestVM {
    inherit name;

    nodes.machine = { config, ... }: {
      imports = [
        testConfig
        commonVmConfig
      ];

      test.shellcheckServices.enable = true;
    };

    testScript = nodes: let
      cfg = nodes.nodes.machine;
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
        cfg.test.extraTestScript
        # Don't run tests in interactive mode.
        # is_interactive is set in ./run-vm.sh
        ''
          if not "is_interactive" in vars():
              nb_run_tests()
        ''
      ];
  };

  mkContainer = legacyInstallDirs:
    extra-container.lib.buildContainers {
      inherit system legacyInstallDirs;
      config = {
        # The container name has a 11 char length limit
        containers.nb-test = { config, ... }: {
          imports = [
            {
              config = {
                extra = config.config.test.container;
                config = testConfig;
              };
            }

            # Enable FUSE inside the container when clightning replication
            # is enabled.
            (
              let
                s = config.config.services;
              in
                lib.mkIf (s ? clightning && s.clightning.enable && s.clightning.replication.enable) {
                  allowedDevices = [ { node = "/dev/fuse"; modifier = "rw"; } ];
                }
            )
          ];
        };
      };
    };

  container = mkContainer false;
  containerLegacy = mkContainer true;

  # This allows running a test scenario in a regular NixOS VM.
  # No tests are executed.
  vm = (pkgs.nixos ({ config, ... }: {
    imports = [
      testConfig
      commonVmConfig
      (pkgs.path + "/nixos/modules/virtualisation/qemu-vm.nix")
    ];
    virtualisation.graphics = false;
    services.getty.autologinUser = "root";

    # Avoid lengthy build of the nixos manual
    documentation.nixos.enable = false;

    # Power off VM when the user exits the shell
    systemd.services."serial-getty@".preStop = ''
      echo o >/proc/sysrq-trigger
    '';

    system.stateVersion = lib.mkDefault config.system.nixos.release;
  })).config.system.build.vm.overrideAttrs (old: {
    meta = old.meta // { mainProgram = "run-vm-in-tmpdir"; };
    buildCommand =  old.buildCommand + "\n" + ''
      install -m 700 ${./run-vm-without-tests.sh} $out/bin/run-vm-in-tmpdir
      patchShebangs $out/bin/run-vm-in-tmpdir
    '';
  });

  commonVmConfig = {
    virtualisation = {
      # Needed because duplicity requires 270 MB of free temp space, regardless of backup size
      diskSize = 1024;

      # Min. 800 MiB needed to avoid 'out of memory' errors
      memorySize = lib.mkDefault 2048;

      # There are no perf gains beyond 3 cores.
      # Benchmark: Ryzen 7 2700 (8 cores), VM test `default` as of 34f6eb90.
      # Num. Cores    | 1   | 2  | 3  | 4  | 6
      # Runtime (sec) | 125 | 95 | 89 | 89 | 90
      cores = lib.mkDefault 3;
    };
  };
in
test // {
  inherit
    vm
    container
    # For NixOS with `system.stateVersion` <22.05
    containerLegacy;

  config = testConfig;
}
