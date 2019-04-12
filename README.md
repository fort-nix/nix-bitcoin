nix-bitcoin
===

Nix packages and nixos modules for easily installing Bitcoin nodes and higher layer protocols.
This is a work in progress - don't expect it to be bug free or secure.

The default configuration sets up a Bitcoin Core node and c-lightning. The user can enable spark-wallet in `configuration.nix` to make c-lightning accessible with a smartphone using spark-wallet.
A simple webpage shows the lightning nodeid and links to nanopos letting the user receive donations.
It also includes liquid-daemon.
Outbound peer-to-peer traffic is forced through Tor, and listening services are bound to onion addresses.

A demo installation is running at [http://6tr4dg3f2oa7slotdjp4syvnzzcry2lqqlcvqkfxdavxo6jsuxwqpxad.onion](http://6tr4dg3f2oa7slotdjp4syvnzzcry2lqqlcvqkfxdavxo6jsuxwqpxad.onion).
The following screen cast shows a fresh deployment of a nix-bitcoin node.

<p align="center">
  <a href="https://asciinema.org/a/223630/?speed=2&autoplay=1"><img src="https://asciinema.org/a/223630.png" height="500"></a>
</p>



The goal is to make it easy to deploy a reasonably secure Bitcoin node with a usable wallet.
It should allow managing bitcoin (the currency) effectively and providing public infrastructure.
It should be a reproducible and extensible platform for applications building on Bitcoin.

Available modules
---
By default the `configuration.nix` provides:
* bitcoind (pruned) with outbound connections through Tor and inbound connections through a hidden
      service. By default loaded with banlist of spy nodes.
* [clightning](https://github.com/ElementsProject/lightning) with outbound connections through Tor, not listening
* includes "nodeinfo" script which prints basic info about the node
* adds non-root user "operator" which has access to bitcoin-cli and lightning-cli

In `configuration.nix` the user can enable:
* a clightning hidden service
* [liquid-daemon](https://github.com/blockstream/liquid)
* [lightning charge](https://github.com/ElementsProject/lightning-charge)
* [nanopos](https://github.com/ElementsProject/nanopos)
* an index page using nginx to display node information and link to nanopos
* [spark-wallet](https://github.com/shesek/spark-wallet)
* [electrs](https://github.com/romanz/electrs)

The data directories of the services can be found in `/var/lib` on the deployed machines.

Installation
---
The easiest way is to run `nix-shell` (on a Linux machine) in the nix-bitcoin directory and then create a [NixOps](https://nixos.org/nixops/manual/) deployment with the provided `network.nix` in the `network` directory.
Fix the FIXMEs in configuration.nix and deploy with nixops in nix-shell.
See [install.md](docs/install.md) for a detailed tutorial.

Hardware requirements
---
* Disk space: 300 GB (235GB for Bitcoin blockchain + some room)
  * Bitcoin Core pruning is not supported at the moment because it's not supported by c-lightning. It's possible to use pruning but you need to know what you're doing.
* RAM: 2GB of memory

Tested hardware includes [pcengine's apu2c4](https://pcengines.ch/apu2c4.htm)

Usage
---
For usage instructions, such as how to connect to spark-wallet, electrs and the ssh Tor Hidden Service, see [usage.md](docs/usage.md).

Troubleshooting
---
If you are having problems with nix-bitcoin check the [FAQ](docs/faq.md) or submit an issue. We are always happy to help.

Docs
---
* [FAQ](docs/faq.md)
* [Install instructions](docs/install.md)
* [Usage instructions](docs/usage.md)
