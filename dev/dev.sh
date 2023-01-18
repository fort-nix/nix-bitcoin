#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Access nix-bitcoin flake packages

function nb() {
    nix build --no-link --print-out-paths --print-build-logs "$@"
}

# A package defined by nix-bitcoin
nb .#joinmarket
# Equivalent
nb .#modulesPkgs.joinmarket

# A nix-bitcoin python package
nb .#nbPython3Packages.pyln-client

# A pinned package from nixpkgs(-unstable)
nb .#pinned.electrs
# Equivalent
nb .#modulesPkgs.electrs

## Eval packages
# Check version
nix eval .#joinmarket.version

# Eval derivation. --raw is needed due to a Nix bug (https://github.com/NixOS/nix/issues/5731)
nix eval --raw .#joinmarket; echo

# Check the version of a package in the nixpkgs(-unstable) inputs of the nix-bitcoin flake
nix eval --inputs-from . nixpkgs#electrs.version
nix eval --inputs-from . nixpkgs-unstable#electrs.version

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Inspect test systems

# Build a test system
nix build -o /tmp/system --print-build-logs "$(nix eval --raw .#tests.default --apply '
  test: test.nodes.machine.system.build.toplevel.drvPath
')"
readlink /tmp/system
# Inspect system files
cat /tmp/system/activate
cat /tmp/system/etc/system/bitcoind.service

# Evaluate a config value
nix eval .#tests.default --apply '
  test: test.nodes.machine.services.bitcoind.rpc.port
'

# Evaluate a config value in a custom test
nix eval .#makeTest --apply '
  makeTest: let
   config = (makeTest {
      config = {
        services.electrs.port = 10000;
      };
    }).nodes.machine;
  in
    config.services.electrs.port
'

# Evaluate a config value in a scenario defined in a file
nix eval --impure .#getTest --apply '
  getTest: let
    config = (getTest {
      name = "default";
      extraScenariosFile = builtins.getEnv("root") + "/scenarios.nix";
    }).nodes.machine;
  in
    config.services.bitcoind.port
'

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Manually run a nix-bitcoin container, without the test framework.
# This allows sharing directories with the container host via option `bindMounts.`

read -rd '' src <<'EOF' || :
  let
    nix-bitcoin = builtins.getFlake "git+file://${toString ../.}";
  in
    nix-bitcoin.inputs.extra-container.lib.buildContainers {
      system = "x86_64-linux";
      inherit (nix-bitcoin.inputs) nixpkgs;
      # legacyInstallDirs = true;
      config = {
        containers.nb-adhoc = {
          # bindMounts."/shared" = { hostPath = "/my/hostpath"; isReadOnly = false; };
          extra.addressPrefix = "10.200.255";
          config = {
            imports = [ nix-bitcoin.nixosModules.default ];
            services.bitcoind.enable = true;
            nix-bitcoin.generateSecrets = true;
            nix-bitcoin.nodeinfo.enable = true;
          };
        };
      };
    }
EOF
nix run --impure --expr "$src"

# Run command in container
nix shell --impure --expr "$src" -c container --run c nodeinfo
# TODO-EXTERNAL: Use this instead when https://github.com/NixOS/nix/issues/7444 is fixed
# nix run --impure --expr "$src" -- --run c nodeinfo

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Show build logs from a CI test run
#
# If a specific test derivation was already built successfully, the test is not rerun
# and the CI logs don't show the test output.

# To view the test output:
# 1. Get the test store path at the end of the CI logs
# 2.
fetch_build_log() {
    local log=$1
    nix cat-store --store https://nix-bitcoin.cachix.org "$log/output.xml" |
        nix shell --inputs-from . nixpkgs#html-tidy -c tidy -xml -i - > /tmp/build-output.xml
    echo
    echo "Fetched log to /tmp/build-output.xml"
}
# Set this to your store path
fetch_build_log /nix/store/0cdjhvg84jsp47f3357812zjmj2wmz94-vm-test-run-nix-bitcoin-default

# Show runtime
grep "script finished in" /tmp/build-output.xml

# View XML with node folding
firefox /tmp/build-output.xml
