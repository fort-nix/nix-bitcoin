<p align="center">
</p>
<br/>
<p align="center">
</p>
<br/>

Docs
---
Hint: To show a table of contents, click the button (![Github TOC button](docs/img/github-table-of-contents.svg)) in the
top left corner of the documents.

<!-- TODO-EXTERNAL: -->
<!-- Change query to `nix-bitcoin` when upstream search has been fixed -->
* [NixOS options search](https://search.nixos.org/flakes?channel=unstable&sort=relevance&type=options&query=bitcoin)
* [Hardware requirements](docs/hardware.md)
* [Configuration and maintenance](docs/configuration.md)
* [Using services](docs/services.md)

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
    * [helpme](https://github.com/lightningd/plugins/tree/master/helpme): walks you through setting up a fresh c-lightning node
    * [monitor](https://github.com/lightningd/plugins/tree/master/monitor): helps you analyze the health of your peers and channels
    * [prometheus](https://github.com/lightningd/plugins/tree/master/prometheus): lightning node exporter for the prometheus timeseries server
    * [rebalance](https://github.com/lightningd/plugins/tree/master/rebalance): keeps your channels balanced
    * [summary](https://github.com/lightningd/plugins/tree/master/summary): print a nice summary of the node status
    * [trustedcoin](https://github.com/nbd-wtf/trustedcoin) [[experimental](docs/services.md#trustedcoin-hints)]: replaces bitcoind with trusted public explorers
    * [zmq](https://github.com/lightningd/plugins/tree/master/zmq): publishes notifications via ZeroMQ to configured endpoints
  * [clightning-rest](https://github.com/Ride-The-Lightning/c-lightning-REST): REST server for clightning
  * [lnd](https://github.com/lightningnetwork/lnd) with support for announcing an onion service and [static channel backups](https://github.com/lightningnetwork/lnd/blob/master/docs/recovery.md)
    * [Lightning Loop](https://github.com/lightninglabs/loop)
    * [Lightning Pool](https://github.com/lightninglabs/pool)
    * [charge-lnd](https://github.com/accumulator/charge-lnd): policy-based channel fee manager
  * [lndconnect](https://github.com/LN-Zap/lndconnect): connect your wallet to lnd or
    clightning [via WireGuard](./docs/services.md#use-zeus-mobile-lightning-wallet-via-wireguard) or
    [Tor](./docs/services.md#use-zeus-mobile-lightning-wallet-via-tor)
  * [Ride The Lightning](https://github.com/Ride-The-Lightning/RTL): web interface for `lnd` and `clightning`
  * [spark-wallet](https://github.com/shesek/spark-wallet)
  * [electrs](https://github.com/romanz/electrs): Electrum server
  * [fulcrum](https://github.com/cculianu/Fulcrum): Electrum server (see [the module](modules/fulcrum.nix) for a comparison with electrs)
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

### Extension modules
Extension modules are maintained in separate repositories and have their own review
and release process.

* [Mempool](https://github.com/fort-nix/nix-bitcoin-mempool): Bitcoin visualizer, explorer and API service


* **Simplicity:** Only services enabled in `configuration.nix` and their dependencies are installed, support for [doas](https://github.com/Duncaen/OpenDoas) ([sudo alternative](https://lobste.rs/s/efsvqu/heap_based_buffer_overflow_sudo_cve_2021#c_c6fcfa)), code is continuously reviewed and refined.
* **Integrity:** The Nix package manager guarantees that all dependencies are exactly specified, packages can be built from source to reduce reliance on binary caches, nix-bitcoin merge commits are signed, all commits are approved by multiple nix-bitcoin developers, upstream packages are cryptographically verified where possible, we use this software ourselves.
ssssssssss
Developing
---
See [dev/README](./dev/README.md).

