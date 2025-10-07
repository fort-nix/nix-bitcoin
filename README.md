<p align="center">
  <img
    width="320"
    src="docs/img/nix-bitcoin-logo.png"
    alt="nix-bitcoin logo">
</p>
<br/>
<p align="center">
    <a href="https://github.com/fort-nix/nix-bitcoin/actions" target="_blank">
        <img src="https://github.com/fort-nix/nix-bitcoin/actions/workflows/test.yml/badge.svg?branch=master"
             alt="Github Actions status">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/releases/latest" target="_blank">
        <img src="https://img.shields.io/github/v/release/fort-nix/nix-bitcoin" alt="GitHub tag (latest SemVer)">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/commits/master" target="_blank">
        <img src="https://img.shields.io/github/commit-activity/y/fort-nix/nix-bitcoin" alt="GitHub commit activity">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/graphs/contributors" target="_blank">
        <img src="https://img.shields.io/github/contributors-anon/fort-nix/nix-bitcoin" alt="GitHub contributors">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/releases" target="_blank">
        <img src="https://img.shields.io/github/downloads/fort-nix/nix-bitcoin/total" alt="GitHub downloads">
    </a>
</p>
<br/>

nix-bitcoin is a collection of Nix packages and NixOS modules for easily installing **full-featured Bitcoin nodes** with an emphasis on **security**.

Overview
---
nix-bitcoin can be used for personal or merchant wallets, public infrastructure or
for Bitcoin application backends. In all cases, the aim is to provide security and
privacy by default. However, while nix-bitcoin is used in production today, it is
still considered experimental.

nix-bitcoin nodes can be deployed on dedicated hardware, virtual machines or containers.
The Nix packages and NixOS modules can be used independently and combined freely.

nix-bitcoin is built on top of Nix and [NixOS](https://nixos.org/) which provide powerful abstractions to keep it highly customizable and
maintainable. Testament to this are nix-bitcoin's robust security features and its potent test framework.  However,
running nix-bitcoin does not require any previous experience with the Nix ecosystem.

Get started
---
- See the [examples](examples/README.md) for an overview of all features.
- To setup a new node from scratch, see the [installation instructions](docs/install.md).
- To add nix-bitcoin to an existing NixOS configuration, see [importable-configuration.nix](examples/importable-configuration.nix)
  and the [Flake example](examples/flakes/flake.nix).

Docs
---
Hint: To show a table of contents, click the button (![Github TOC button](docs/img/github-table-of-contents.svg)) in the
top left corner of the documents.

<!-- TODO-EXTERNAL: -->
<!-- Change query to `nix-bitcoin` when upstream search has been fixed -->
* [NixOS options search](https://search.nixos.org/flakes?channel=unstable&sort=relevance&type=options&query=bitcoin)
* [Hardware requirements](docs/hardware.md)
* [Installation](docs/install.md)
* [Configuration and maintenance](docs/configuration.md)
* [Using services](docs/services.md)
* [FAQ](docs/faq.md)

Features
---
A [configuration preset](modules/presets/secure-node.nix) for setting up a secure node
* All applications use Tor for outbound connections and support accepting inbound connections via onion services.

NixOS modules ([src](modules/modules.nix))
* Application services
  * [bitcoind](https://github.com/bitcoin/bitcoin)
  * [clightning](https://github.com/ElementsProject/lightning) with support for announcing an onion service
    and [database replication](docs/services.md#setup-clightning-database-replication).\
    Available plugins:
    * [clboss](https://github.com/ZmnSCPxj/clboss): automated C-Lightning Node Manager
    * [currencyrate](https://github.com/lightningd/plugins/tree/master/currencyrate): currency converter
    * [monitor](https://github.com/lightningd/plugins/tree/master/monitor): helps you analyze the health of your peers and channels
    * [rebalance](https://github.com/lightningd/plugins/tree/master/rebalance): keeps your channels balanced
    * [trustedcoin](https://github.com/nbd-wtf/trustedcoin) ([experimental](docs/services.md#trustedcoin)): replaces bitcoind with trusted public explorers
    * [teos-watchtower](https://github.com/talaia-labs/rust-teos/tree/master/watchtower-plugin): watchtower client plugin [to interact](docs/services.md#the-eye-of-satoshi-watchtower-plugin) with an Eye of Satoshi tower
    * [zmq](https://github.com/lightningd/plugins/tree/master/zmq): publishes notifications via ZeroMQ to configured endpoints
  * [lnd](https://github.com/lightningnetwork/lnd) with support for announcing an onion service and [static channel backups](https://github.com/lightningnetwork/lnd/blob/master/docs/recovery.md)
    * [Lightning Loop](https://github.com/lightninglabs/loop)
    * [Lightning Pool](https://github.com/lightninglabs/pool)
    * [charge-lnd](https://github.com/accumulator/charge-lnd): policy-based channel fee manager
  * [lndconnect](https://github.com/LN-Zap/lndconnect): connect your wallet to lnd or
    clightning [via WireGuard](./docs/services.md#use-zeus-mobile-lightning-wallet-via-wireguard) or
    [Tor](./docs/services.md#use-zeus-mobile-lightning-wallet-via-tor)
  * [Ride The Lightning](https://github.com/Ride-The-Lightning/RTL): web interface for `lnd` and `clightning`
  * [mempool](https://github.com/mempool/mempool): Bitcoin visualizer, explorer, and API service
  * [electrs](https://github.com/romanz/electrs): Electrum server
  * [fulcrum](https://github.com/cculianu/Fulcrum): Electrum server (see [the module](modules/fulcrum.nix) for a comparison with electrs)
  * [teos](https://github.com/talaia-labs/rust-teos) a Lightning watchtower
  * [btcpayserver](https://github.com/btcpayserver/btcpayserver)
  * [liquid](https://github.com/elementsproject/elements): federated sidechain
  * [JoinMarket](https://github.com/joinmarket-org/joinmarket-clientserver)
    * [JoinMarket Orderbook Watcher](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/orderbook.md)
  * [bitcoin-core-hwi](https://github.com/bitcoin-core/HWI)
* Helper
  * [netns-isolation](modules/netns-isolation.nix): isolates applications on the network-level via network namespaces
  * [nodeinfo](modules/nodeinfo.nix): script which prints info about the node's services
  * [backups](modules/backups.nix): duplicity backups of all your node's important files
  * [operator](modules/operator.nix): configures a non-root user who has access to client tools (e.g. `bitcoin-cli`, `lightning-cli`)

Security
---
See [SECURITY.md](SECURITY.md) for the security policy and how to report a vulnerability.

nix-bitcoin aims to achieve a high degree of security by building on the following principles:

* **Simplicity:** Only services enabled in `configuration.nix` and their dependencies are installed, support for [doas](https://github.com/Duncaen/OpenDoas) ([sudo alternative](https://lobste.rs/s/efsvqu/heap_based_buffer_overflow_sudo_cve_2021#c_c6fcfa)), code is continuously reviewed and refined.
* **Integrity:** The Nix package manager guarantees that all dependencies are exactly specified, packages can be built from source to reduce reliance on binary caches, nix-bitcoin merge commits are signed, all commits are approved by multiple nix-bitcoin developers, upstream packages are cryptographically verified where possible, we use this software ourselves.
* **Principle of Least Privilege:** Services operate with least privileges; they each have their own user and are restricted further with [systemd features](pkgs/lib.nix), [RPC whitelisting](modules/bitcoind-rpc-public-whitelist.nix) and [netns-isolation](modules/netns-isolation.nix). There's a non-root user *operator* to interact with the various services.
* **Defense-in-depth:** nix-bitcoin supports a [hardened kernel](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix), services are confined through discretionary access control, Linux namespaces, [dbus firewall](modules/security.nix) and seccomp-bpf with continuous improvements.

Note that if the machine you're deploying *from* is insecure, there is nothing nix-bitcoin can do to protect itself.

Security fund
---
The nix-bitcoin security fund is a 2 of 3 bitcoin multisig address open for donations, used to reward
security researchers who discover vulnerabilities in nix-bitcoin or its upstream dependencies.\
See [Security Fund](./SECURITY.md#nix-bitcoin-security-fund) for details.

Developing
---
See [dev/README](./dev/README.md).

Troubleshooting
---
If you are having problems with nix-bitcoin check the [FAQ](docs/faq.md) or submit an issue.\
There's also a Matrix room at [#general:nixbitcoin.org](https://matrix.to/#/#general:nixbitcoin.org).\
We are always happy to help.
