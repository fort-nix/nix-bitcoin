## Examples

The easiest way to try out nix-bitcoin is to use one of the provided examples.

### Flakes-based quick start

If you use a Flakes-enabled version of Nix, run the following command to start a minimal
nix-bitcoin QEMU VM:
```bash
nix run github:fort-nix/nix-bitcoin/release
```
The VM (defined in [flake.nix](../flake.nix)) runs in the terminal and has `bitcoind`
and `clightning` installed.\
It leaves no traces (outside of `/nix/store`) on the host system.


### More examples

Clone this repo and enter the examples shell:
```bash
git clone https://github.com/fort-nix/nix-bitcoin
cd nix-bitcoin/examples/
nix-shell
```

The following example scripts set up a nix-bitcoin node according to [`./configuration.nix`](configuration.nix) and then
shut down immediately. They leave no traces (outside of `/nix/store`) on the host system.\
By default, [`./configuration.nix`](configuration.nix) enables `bitcoind` and `clightning`.

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
The [nix-bitcoin test suite](../test/README.md) is also useful for exploring features.

### Real-world example
Check the [server repo](https://github.com/fort-nix/nixbitcoin.org) for https://nixbitcoin.org
to see the configuration of a Flakes-based nix-bitcoin node that's used in production.

The commands in `shell.nix` allow you to locally run the node in a VM or container.

### Flakes

Flakes make it easy to include `nix-bitcoin` in an existing NixOS config.
The [flakes example](./flakes/flake.nix) shows how to use `nix-bitcoin` as an input to a system flake.

### Using Bitcoin Knots Instead of bitcoind

nix-bitcoin now supports running [Bitcoin Knots](https://bitcoinknots.org/) as an alternative to Bitcoin Core (bitcoind).

**To use Bitcoin Knots instead of bitcoind:**

- In your `configuration.nix` (or flake module), set:

```nix
{
  services.bitcoind.enable = false;
  services.bitcoin-knots.enable = true;
  # Optionally, set Knots-specific options:
  # services.bitcoin-knots.knotsSpecificOptions = { ... };
}
```

- Only one of `bitcoind` or `bitcoin-knots` should be enabled at a time.
- All standard bitcoind configuration options are supported. Knots-specific options can be set via `knotsSpecificOptions`.

For more advanced switching (e.g., via Flakes), see the main INSTRUCTIONS.md.

### Persistent container with Flakes

The [persistent container](./container) example shows how to run a Flake-based node
in a container.\
Requires: A systemd-based Linux distro and root privileges.

### Extending nix-bitcoin with Flakes

The [mempool extension flake](https://github.com/fort-nix/nix-bitcoin-mempool) shows how to define new
pkgs and modules in a Flake.\
Since mempool is now a core nix-bitcoin module, this Flake just serves as an example.
