Examples
---

The easiest way to try out nix-bitcoin is to use one of the provided examples.

```bash
git clone https://github.com/fort-nix/nix-bitcoin
cd nix-bitcoin/examples/
nix-shell
```

The following example scripts set up a nix-bitcoin node according to [`configuration.nix`](configuration.nix) and then
shut down immediately. They leave no traces (outside of `/nix/store`) on the host system.\
By default, [`configuration.nix`](configuration.nix) enables `bitcoind` and `clightning`.

- [`./deploy-container.sh`](deploy-container.sh) creates a [NixOS container](https://github.com/erikarvstedt/extra-container).\
  This is the fastest way to set up a node.\
  Requires: [Nix](https://nixos.org/), a systemd-based Linux distro and root privileges

- [`./deploy-qemu-vm.sh`](deploy-qemu-vm.sh) creates a QEMU VM.\
  Requires: [Nix](https://nixos.org/nix/), Linux

- [`./deploy-krops.sh`](deploy-krops.sh) creates a QEMU VM and deploys a
  nix-bitcoin configuration to it using [krops](https://github.com/krebs/krops).\
  Requires: [Nix](https://nixos.org/nix/), Linux

- [`./deploy-container-minimal.sh`](deploy-container-minimal.sh) creates a
  container defined by [importable-configuration.nix](importable-configuration.nix).\
  You can copy and import this file to use nix-bitcoin in an existing NixOS configuration.\
  The configuration doesn't use the [secure-node.nix](../modules/presets/secure-node.nix) preset.\
  Requires: [Nix](https://nixos.org/), a systemd-based Linux distro and root privileges

Run the examples with option `--interactive` or `-i` to start a shell for interacting with
the node:
```bash
./deploy-qemu-vm.sh -i
```

### Tests
The internal test suite is also useful for exploring features.\
The following `run-tests.sh` commands leave no traces (outside of `/nix/store`) on
the host system.

```bash
git clone https://github.com/fort-nix/nix-bitcoin
cd nix-bitcoin/test

# Run a node in a VM. No tests are executed.
./run-tests.sh vm
systemctl status bitcoind

# Run a Python test shell inside a VM node
./run-tests.sh debug
print(succeed("systemctl status bitcoind"))
run_test("bitcoind")

# Run a node in a container. Requires systemd and root privileges.
./run-tests.sh container
c systemctl status bitcoind

# Explore a single feature
./run-tests.sh --scenario electrs container

# Run a command in a container
./run-tests.sh --scenario '{
  services.clightning.enable = true;
  nix-bitcoin.nodeinfo.enable = true;
}' container --run c nodeinfo
```
See [`run-tests.sh`](../test/run-tests.sh) for a complete documentation.

### Real-world example
Check the [server repo](https://github.com/fort-nix/nixbitcoin.org) for https://nixbitcoin.org
to see the configuration of a nix-bitcoin node that's used in production.

The commands in `shell.nix` allow you to locally run the node in a VM or container.

### Flakes

Flakes make it easy to include `nix-bitcoin` in an existing NixOS config.
The [flakes example](./flakes/flake.nix) shows how to use `nix-bitcoin` as an input to a system flake.

Run `nix run` or `nix run .#vm` from the nix-bitcoin root directory to start an example
nix-bitcoin node VM.
This command is defined by the nix-bitcoin flake (in [flake.nix](../flake.nix)).
