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
  Requires: [Nix](https://nixos.org/nix/)

- [`./deploy-nixops.sh`](deploy-nixops.sh) creates a VirtualBox VM via [NixOps](https://github.com/NixOS/nixops).\
  NixOps can be used to deploy to various other backends like cloud providers.\
  Requires: [Nix](https://nixos.org/nix/), [VirtualBox](https://www.virtualbox.org)

- [`./deploy-container-minimal.sh`](deploy-container-minimal.sh) creates a
  container defined by [minimal-configuration.nix](minimal-configuration.nix) that
  doesn't use the [secure-node.nix](../modules/presets/secure-node.nix) preset.
  Also shows how to use nix-bitcoin in an existing NixOS config.\
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

# Run a Python test shell inside a VM node
./run-tests.sh debug
print(succeed("systemctl status bitcoind"))

# Run a node in a container. Requires systemd and root privileges.
./run-tests.sh container
c systemctl status bitcoind

# Explore a single feature
./run-tests.sh --scenario electrs container
```
See [`run-tests.sh`](../test/run-tests.sh) for a complete documentation.
