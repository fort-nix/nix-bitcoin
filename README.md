<p align="center">
  <img
    width="320"
    src="docs/img/nix-bitcoin-logo.png"
    alt="nix-bitcoin logo">
</p>
<br/>
<p align="center">
    <a href="https://cirrus-ci.com/github/fort-nix/nix-bitcoin" target="_blank">
        <img src="https://api.cirrus-ci.com/github/fort-nix/nix-bitcoin.svg?branch=master" alt="CirrusCI status">
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
A Bitcoin node verifies the Bitcoin protocol and provides ways of interacting with the Bitcoin network. nix-bitcoin
nodes are used for a variety of purposes and can serve as personal or merchant wallets, second layer public
infrastructure and as backends for Bitcoin applications. In all cases, the aim is to provide security and privacy by
default. However, while nix-bitcoin is used in production today, it is still considered experimental.

A full installation of nix-bitcoin is usually deployed either on a dedicated (virtual) machine or runs in a container
and is online 24/7. Alternatively, the Nix packages, NixOS modules and configurations can be used independently and
combined freely.

nix-bitcoin is built on top of Nix and NixOS which provide powerful abstractions to keep it highly customizable and
maintainable. Testament to this are nix-bitcoin's robust security features and its potent test framework.  However,
running nix-bitcoin does not require any previous experience with the Nix ecosystem.

Examples
---
See [here for examples](examples/README.md).

Features
---
A [configuration preset](modules/presets/secure-node.nix) for setting up a secure node
* All applications use Tor for outbound connections and support accepting inbound connections via onion services.

NixOS modules
* Application services
  * [bitcoind](https://github.com/bitcoin/bitcoin), with a default banlist against spy nodes
  * [clightning](https://github.com/ElementsProject/lightning) with support for announcing an onion service\
    Available plugins:
    * [clboss](https://github.com/ZmnSCPxj/clboss): automated C-Lightning Node Manager
    * [helpme](https://github.com/lightningd/plugins/tree/master/helpme): walks you through setting up a fresh c-lightning node
    * [monitor](https://github.com/renepickhardt/plugins/tree/master/monitor): helps you analyze the health of your peers and channels
    * [prometheus](https://github.com/lightningd/plugins/tree/master/prometheus): lightning node exporter for the prometheus timeseries server
    * [rebalance](https://github.com/lightningd/plugins/tree/master/rebalance): keeps your channels balanced
    * [summary](https://github.com/lightningd/plugins/tree/master/summary): print a nice summary of the node status
    * [zmq](https://github.com/lightningd/plugins/tree/master/zmq): publishes notifications via ZeroMQ to configured endpoints
  * [lnd](https://github.com/lightningnetwork/lnd) with support for announcing an onion service
    * [lndconnect](https://github.com/LN-Zap/lndconnect) via a REST onion service
  * [spark-wallet](https://github.com/shesek/spark-wallet)
  * [electrs](https://github.com/romanz/electrs)
  * [btcpayserver](https://github.com/btcpayserver/btcpayserver)
  * [liquid](https://github.com/elementsproject/elements)
  * [Lightning Loop](https://github.com/lightninglabs/loop)
  * [JoinMarket](https://github.com/joinmarket-org/joinmarket-clientserver)
    * [JoinMarket Orderbook Watcher](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/orderbook.md)
  * [recurring-donations](modules/recurring-donations.nix): for periodic lightning payments
  * [bitcoin-core-hwi](https://github.com/bitcoin-core/HWI)
* Helper
  * [netns-isolation](modules/netns-isolation.nix): isolates applications on the network-level via network namespaces
  * [nodeinfo](modules/nodeinfo.nix): script which prints info about the node's services
  * [backups](modules/backups.nix): duplicity backups of all your node's important files
  * [operator](modules/operator.nix): adds non-root user `operator` who has access to client tools (e.g. `bitcoin-cli`, `lightning-cli`)

Security
---
* **Simplicity:** Only services you select in `configuration.nix` and their dependencies are installed, packages and dependencies are [pinned](pkgs/nixpkgs-pinned.nix), support for [doas](https://github.com/Duncaen/OpenDoas) ([sudo alternative](https://lobste.rs/s/efsvqu/heap_based_buffer_overflow_sudo_cve_2021#c_c6fcfa)), most packages are built from the [NixOS stable channel](https://github.com/NixOS/nixpkgs/tree/nixos-20.09), with a few exceptions that are built from the nixpkgs unstable channel, builds happen in a [sandboxed environment](https://nixos.org/manual/nix/stable/#conf-sandbox), code is continuously reviewed and refined.
* **Integrity:** Nix package manager, NixOS and packages can be built from source to reduce reliance on binary caches, nix-bitcoin merge commits are signed, all commits are approved by multiple nix-bitcoin developers, upstream packages are cryptographically verified where possible, we use this software ourselves.
* **Principle of Least Privilege:** Services operate with least privileges; they each have their own user and are restricted further with [systemd options](pkgs/lib.nix), [RPC whitelisting](modules/bitcoind-rpc-public-whitelist.nix), and [netns-isolation](modules/netns-isolation.nix). There's a non-root user *operator* to interact with the various services.
* **Defense-in-depth:** nix-bitcoin is built with a [hardened kernel](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix) by default, services are confined through discretionary access control, Linux namespaces, [dbus firewall](modules/security.nix) and seccomp-bpf with continuous improvements.

Note that if the machine you're deploying *from* is insecure, there is nothing nix-bitcoin can do to protect itself.

Docs
---
* [FAQ](docs/faq.md)
* [Hardware Requirements](docs/hardware.md)
* [Install instructions](docs/install.md)
* [Usage instructions](docs/usage.md)

Troubleshooting
---
If you are having problems with nix-bitcoin check the [FAQ](docs/faq.md) or submit an issue.
There's also a `#nix-bitcoin` IRC channel on freenode.
We are always happy to help.
