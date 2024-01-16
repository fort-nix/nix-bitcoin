The [`run-tests.sh`](./run-tests.sh) command is the most convenient and versatile way to run tests.\
It leave no traces (outside of `/nix/store`) on the host system.

`run-tests.sh` requires Nix >= 2.10.

### Summary
```bash
./run-tests.sh [--scenario|-s <scenario>] [build|vm|debug|container]
```

See the top of [run-tests.sh](../test/run-tests.sh) for a complete documentation.\
Test scenarios are defined in [tests.nix](./tests.nix) and [tests.py](tests.py).

### Tutorial
#### Running tests
```bash
# Run the basic set of tests. These tests are also run on the GitHub CI server.
./run-tests.sh

# Run the test for scenario `regtest`.
# The test is run via the Nix build system. Successful runs are cached.
./run-tests.sh -s regtest build
./run-tests.sh -s regtest # Shorthand, equivalent

# To test a single service, use its name as a scenario.
./run-tests.sh -s clightning

# When no scenario is specified, scenario `default` is used.
./run-tests.sh build
```
#### Debugging
```bash
# Start a shell inside a test VM. No tests are executed.
./run-tests.sh -s bitcoind vm
systemctl status bitcoind

# Run a Python NixOS test shell inside a VM.
# See https://nixos.org/manual/nixos/stable/#ssec-machine-objects for available commands.
./run-tests.sh debug
print(succeed("systemctl status bitcoind"))
run_test("bitcoind")

# Start a shell in a container node. Requires systemd and root privileges.
./run-tests.sh container

# In the container shell: Run command in container (with prefix `c`)
c systemctl status bitcoind

# Explore a single feature
./run-tests.sh -s electrs container

# Run a command in a container.
# The container is deleted afterwards.
./run-tests.sh -s clightning container --run c lightning-cli getinfo

# Define a custom scenario
./run-tests.sh --scenario '{
  services.clightning.enable = true;
  nix-bitcoin.nodeinfo.enable = true;
}' container --run c nodeinfo
```

# Running tests with Flakes

Tests can also be accessed via the nix-bitcoin flake:

```bash
# Build test
nix build --no-link ..#tests.default

# Run a node in a VM. No tests are executed.
nix run ..#tests.default.vm

# Run a Python test shell inside a VM node
nix run ..#tests.default.run -- --debug

# Run a node in a container. Requires extra-container, systemd and root privileges
nix run ..#tests.default.container
nix run ..#tests.default.containerLegacy # For NixOS with `system.stateVersion` <22.05

# Run a command in a container
nix run ..#tests.default.container -- --run c nodeinfo
nix run ..#tests.default.containerLegacy -- --run c nodeinfo # For NixOS with `system.stateVersion` <22.05
```
