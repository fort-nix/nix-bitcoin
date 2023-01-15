# Managing your deployment

This section applies to users of the deployment method described in the [installation guide](./install.md).

## Deployment shell
Run command `nix-shell` in your deployment directory.\
You now have access to deployment commands:

- `deploy`\
  Deploy the current configuration to your node.
- `eval-config`\
  Locally evaluate the configuration. This is useful to check for configuration errors.
- `h`, `help`\
  Show help

## Updating nix-bitcoin
Run `update-nix-bitcoin` from the deployment shell.\
This fetches the latest release, verifies its signatures and updates `nix-bitcoin-release.nix`.

# Customizing your configuration

## Get started with Nix

See [Nix - A One Pager](https://github.com/tazjin/nix-1p) for a short guide
to Nix, the language used in `configuration.nix`.\
You can follow along this guide by running command `nix repl` which allows you to interactively
evaluate Nix expressions.

For a general introduction to the Nix and NixOS ecosystem, see [nix.dev](https://nix.dev/).

## Set options

All features and services are configurable through options. You can find a list of
supported options at the top of each nix-bitcoin [module](../modules/modules.nix)
(Examples: [bitcoind.nix](../modules/bitcoind.nix), [btcpayserver.nix](../modules/btcpayserver.nix)).

Example: Set some `bitcoind` options by adding these lines to your `configuration.nix`:
```nix
# Use a custom data dir
services.bitcoind.dataDir = "/my/datadir";

# Enable txindex
services.bitcoind.txindex = true;
```

You can also use regular [NixOS options](https://search.nixos.org/options)
for configuring your system:
```nix
networking.hostName = "myhost";
time.timeZone = "UTC";
```

## Debug your configuration

To print the values of specific options of your config, add the following to your `configuration.nix`:
```nix
system.extraDependencies = let
  debugVal = config.networking.firewall.allowedTCPPorts;
  # More example options:
  # debugVal = config.environment.systemPackages;
  # debugVal = config.services.bitcoind.dataDir;
in lib.traceSeqN 3 debugVal [];
```
and run command `eval-config` from the deployment shell.

# Allowing external connections to services

## Allow peer connections to bitcoind

```nix
services.bitcoind = {
  # Accept incoming peer connections
  listen = true;

  # Listen to connections on all interfaces
  address = "0.0.0.0";

  # Set this to also add IPv6 connectivity.
  extraConfig = ''
    bind=::
  '';

  # If you're using the `secure-node.nix` template, set this to allow non-Tor connections
  # to bitcoind
  tor.enforce = false;
  # Also set this if bitcoind should not use Tor for outgoing peer connections
  tor.proxy = false;
};

# Open the p2p port in the firewall
networking.firewall.allowedTCPPorts = [ config.services.bitcoind.port ];
```

## Allow bitcoind RPC connections from LAN

```nix
services.bitcoind = {
  # Listen to RPC connections on all interfaces
  rpc.address = "0.0.0.0";

  # Allow RPC connections from external addresses
  rpc.allowip = [
    "10.10.0.0/24" # Allow a subnet
    "10.50.0.3" # Allow a specific address
    "0.0.0.0/0" # Allow all addresses
  ];

  # Set this if you're using the `secure-node.nix` template
  tor.enforce = false;
};

# Open the RPC port in the firewall
networking.firewall.allowedTCPPorts = [ config.services.bitcoind.rpc.port ];
```

## Allow connections to electrs

```nix
services.electrs = {
  # Listen to connections on all interfaces
  address = "0.0.0.0";

  # Set this if you're using the `secure-node.nix` template
  tor.enforce = false;
};

# Open the electrs port in the firewall
networking.firewall.allowedTCPPorts = [ config.services.electrs.port ];
```

You can use the same approach to allow connections to other services.

# Migrate existing services to nix-bitcoin

## Example: bitcoind

```shell
# 1. Stop bitcoind on your node
ssh root@nix-bitcoin-node 'systemctl stop bitcoind'
# Also stop bitcoind on the node that you'll be copying data from

# 2. Copy the data to the nix-bitcoin node
# Important: Add a trailing slash to the source path
rsync /path/to/existing/bitcoind-datadir/ root@nix-bitcoin-node:/var/lib/bitcoind

# 3. Fix data dir permissions on the nix-bitcoin node
ssh root@nix-bitcoin-node 'chown -R bitcoin: /var/lib/bitcoind'

# 4. Start bitcoind
ssh root@nix-bitcoin-node 'systemctl start bitcoind'
```

You can use the same workflow for other services.\
The default data dir path is `/var/lib/<service>` for all services.

Some services require extra steps:

- lnd

  Copy your wallet password to `$secretsDir/lnd-wallet-password` (See: [Secrets dir](#secrets-dir)).

- btcpayserver

  Copy the postgresql database:
  ```shell
  # Export (on the other node)
  sudo -u postgres pg_dump YOUR_BTCPAYSERVER_DB > export.sql
  # Restore (on the nix-bitcoin node)
  sudo -u postgres psql btcpaydb < export.sql
  ```

- joinmarket

  Copy your wallet to `/var/lib/joinmarket/wallets/wallet.jmdat`.\
  Write your wallet password, without a trailing newline, to
  `$secretsDir/jm-wallet-password` (See: [Secrets dir](#secrets-dir)).

# Use bitcoind from another node

Here's how to use a bitcoind instance running on another node within a nix-bitcoin config:

```nix
imports = [ <nix-bitcoin/modules/presets/bitcoind-remote.nix> ];

services.bitcoind = {
  enable = true;

  # Address of the other node
  address = "10.10.0.2";
  rpc.address = "10.10.0.2";

  # Some nix-bitcoin services require whitelisted bitcoind p2p connections
  # to work reliably.
  # Search for `whitelistedPort` in this repo to see the affected services.
  # If you're using one of these services, either add a whitelisted p2p port
  # on your remote node via `whitebind` and set it here:
  whitelistedPort = <remote whitebind RPC port>;
  #
  # Or use the default p2p port and add `whitelist=<address of this node>` to
  # your remote bitcoind config:
  whitelistedPort = config.services.bitcoind.port;

  rpc.users = let
    # The fully privileged bitcoind RPC username of the other node
    name = "myrpcuser";
  in {
    privileged.name = name;
    public.name = name;
    ## Set this if you use btcpayserver
    # btcpayserver.name = name;
    ## Set this if you use joinmarket-ob-watcher
    # joinmarket-ob-watcher.name = name;
  };
};
```

For each service that connects to bitcoind and has option
`services.<service>.tor.enforce` enabled (either explicitly or by importing
`secure-node.nix` or `enable-tor.nix`), you need to
allow the remote bitcoind connection:
```nix
systemd.services.<service>.serviceConfig.IPAddressAllow = [ ${services.bitcoind.rpc.address} ];
```

> The above configuration is only required if the remote bitcoind **is
> not** accessed via Tor.


Now save the password of the RPC user to the following files on your nix-bitcoin node:
```shell
$secretsDir/bitcoin-rpcpassword-privileged
$secretsDir/bitcoin-rpcpassword-public

## Only needed when set in the above config snippet
# $secretsDir/bitcoin-rpcpassword-btcpayserver
# $secretsDir/bitcoin-rpcpassword-joinmarket-ob-watcher
```
See: [Secrets dir](#secrets-dir)

Afterwards, restart `bitcoind`: `systemctl restart bitcoind`.

# Temporarily disable a service

Sometimes you might want to disable a service without removing the service user and
integration with other services, as it would happen when setting
`services.<service>.enable = false`.

Use the following approach:
```
systemd.services.<service>.wantedBy = mkForce [];
```
This way, the systemd service still exists, but is not automatically started.\
Note: This only works for services that are not required by other active services.

# Appendix

## Secrets dir

The secrets dir is set by option `nix-bitoin.secretsDir` and has the
following default values:

- If you're using the krops deployment method: `/var/src/secrets`

- Otherwise: `/etc/nix-bitcoin-secrets`
