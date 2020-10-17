# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }: {
  imports = [
    <nix-bitcoin/modules/presets/secure-node.nix>

    # FIXME: The hardened kernel profile improves security but
    # decreases performance by ~50%.
    # Turn it off when not needed.
    # Source: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix
    <nixpkgs/nixos/modules/profiles/hardened.nix>

    # FIXME: Uncomment next line to import your hardware configuration. If so,
    # add the hardware configuration file to the same directory as this file.
    # This is not needed when deploying to a virtual box.
    #./hardware-configuration.nix
  ];
  # FIXME: Enable modules by uncommenting their respective line. Disable
  # modules by commenting out their respective line.

  ### BITCOIND
  # Bitcoind is enabled by default if nix-bitcoin is enabled
  #
  # Enable this option to set pruning to a specified MiB value.
  # clightning is compatible with pruning. See
  # https://github.com/ElementsProject/lightning/#pruning for more information.
  # LND and electrs are not compatible with pruning.
  # services.bitcoind.prune = 100000;
  #
  # You can add options that are not defined in modules/bitcoind.nix as follows
  # services.bitcoind.extraConfig = ''
  #   maxorphantx=110
  # '';

  ### CLIGHTNING
  # Enable this module to use clightning, a Lightning Network implementation
  # in C.
  services.clightning.enable = true;
  # Enable this option to announce our Tor Hidden Service. By default clightning
  # offers outgoing functionality, but doesn't announce the Tor Hidden Service
  # under which peers can reach us.
  # services.clightning.announce-tor = true;

  ### LND
  # Uncomment the following line in order to enable lnd, a lightning
  # implementation written in Go. In order to avoid collisions with clightning
  # you must disable clightning or change the services.clightning.bindport or
  # services.lnd.listenPort to a port other than 9735.
  # services.lnd.enable = true;
  # Enable this option to announce our Tor Hidden Service. By default lnd
  # offers outgoing functionality, but doesn't announce the Tor Hidden Service
  # under which peers can reach us.
  # services.lnd.announce-tor = true;
  ## WARNING
  # If you use lnd, you should manually backup your wallet mnemonic
  # seed. This will allow you to recover on-chain funds. You can run the
  # following command after the lnd service starts:
  # nixops scp --from bitcoin-node /secrets/lnd-seed-mnemonic ./secrets/lnd-seed-mnemonic
  # You should also backup your channel state after opening new channels.
  # This will allow you to recover off-chain funds, by force-closing channels.
  # nixops scp --from bitcoin-node /var/lib/lnd/chain/bitcoin/mainnet/channel.backup /my-backup-path/channel.backup

  ### SPARK WALLET
  # Enable this module to use spark-wallet, a minimalistic wallet GUI for
  # c-lightning, accessible over the web or through mobile and desktop apps.
  # Only available if clightning is enabled.
  # services.spark-wallet.enable = true;

  ### ELECTRS
  # Enable this module to use electrs, an efficient re-implementation of
  # Electrum Server in Rust.
  # services.electrs.enable = true;
  # If you have more than 8GB memory, enable this option so electrs will
  # sync faster. Only available if hardware wallets are disabled.
  # services.electrs.high-memory = true;

  ### BTCPayServer
  # Enable this module to use BTCPayServer, a self-hosted, open-source
  # cryptocurrency payment processor.
  # Privacy Warning: BTCPayServer currently looks up price rates without
  # proxying them through Tor. This means an outside observer can correlate
  # your BTCPayServer usage, like invoice creation times, with your IP address.
  # services.btcpayserver.enable = true;
  # Enable this option to connect BTCPayServer to clightning.
  # services.btcpayserver.lightningBackend = "clightning";
  # Enable this option to connect BTCPayServert to lnd.
  # services.btcpayserver.lightningBackend = "lnd";
  # Afterwards you need to go into Store > General Settings > Lightning Nodes
  # and click to use "the internal lightning node of this BTCPay Server".

  ### LIQUIDD
  # Enable this module to use Liquid, a sidechain for an inter-exchange
  # settlement network linking together cryptocurrency exchanges and
  # institutions around the world. Liquid is accessed with the elements-cli
  # tool run as user operator.
  # services.liquidd.enable = true;

  ### LIGHTNING CHARGE
  # Enable this module to use lightning-charge, a simple drop-in solution for
  # accepting lightning payments. Only available if clightning is enabled.
  # services.lightning-charge.enable = true;

  ### NANOPOS
  # Enable this module to use nanopos, a simple Lightning point-of-sale
  # system, powered by Lightning Charge. Only available if clightning and
  # lightning-charge are enabled.
  # services.nanopos.enable = true;

  ### WEBINDEX
  # Enable this module to use the nix-bitcoin-webindex, a simple website
  # displaying your node information and link to nanopos store. Only available
  # if clightning, lightning-charge, and nanopos are enabled.
  # services.nix-bitcoin-webindex.enable = true;

  ### RECURRING-DONATIONS
  # Enable this module to send recurring donations. This is EXPERIMENTAL; it's
  # not guaranteed that payments are succeeding or that you will notice payment
  # failure. Only available if clightning is enabled.
  # services.recurring-donations.enable = true;
  # Specify the receivers of the donations. By default donations are every
  # Monday at a randomized time. Check `journalctl -eu recurring-donations` or
  # `lightning-cli listpayments` for successful lightning donations.
  # services.recurring-donations.tallycoin = {
  #   "<receiver name>" = <amount you wish to donate in sat>"
  #   "<additional receiver name>" = <amount you wish to donate in sat>;
  #   "djbooth007" = 1000;
  # };

  ### Hardware wallets
  # Enable this module to allow using hardware wallets. See https://github.com/bitcoin-core/HWI
  # for more information. Only available if electrs.high-memory is disabled.
  # Ledger must be initialized through the official ledger live app and the Bitcoin app must
  # be installed and running on the device.
  # services.hardware-wallets.ledger = true;
  # Trezor can be initialized with the trezorctl command in nix-bitcoin. More information in
  # `docs/usage.md`.
  # services.hardware-wallets.trezor = true;

  ### netns-isolation (EXPERIMENTAL)
  # Enable this module to use Network Namespace Isolation. This feature places
  # every service in its own network namespace and only allows truly necessary
  # connections between network namespaces, making sure services are isolated on
  # a network-level as much as possible.
  # nix-bitcoin.netns-isolation.enable = true;

  ### lightning-loop
  # Enable this module to use lightninglab's non-custodial off/on chain bridge.
  # loopd (lightning-loop daemon) will be started automatically. Users can
  # interact with off/on chain bridge using `loop in` and `loop out`.
  # services.lightning-loop.enable = true;

  ### Backups
  # Enable this module to use nix-bitcoin's own backups module. By default, it
  # uses duplicity to incrementally back up all important files in /var/lib to
  # /var/lib/localBackups once a day.
  # services.backups.enable = true;
  # You can pull the localBackups folder with
  # `nixops scp --from bitcoin-node /var/lib/localBackups /my-backup-path/`
  # Alternatively, you can also set a remote target url, for example
  # services.backups.destination = "sftp://user@host[:port]/[relative|/absolute]_path";
  # Supply the sftp password by appending the FTP_PASSWORD environment variable
  # to secrets/backup-encryption-env like so
  # `echo "FTP_PASSWORD=<password>" >> secrets/backup-encryption-env`
  # You many also need to set a ssh host and publickey with
  # programs.ssh.knownHosts."host" = {
  #   hostNames = [ "host" ];
  #   publicKey = "<ssh public from `ssh-keyscan`>";
  # };
  # If you also want to backup bulk data like the Bitcoin & Liquid blockchains
  # and electrs data directory, enable
  # services.backups.with-bulk-data = true;

  ### JOINMARKET
  # Enable this module to allow using JoinMarket's user interactive scripts (including
  # tumbler.py).
  # Note: JoinMarket has full access to bitcoind, including its wallet functionality.
  # services.joinmarket.enable = true;
  # Enable this option to enable the JoinMarket Yield Generator Bot. You will be able to
  # earn sats by providing CoinJoin liquidity. This makes it impossible to use other
  # scripts that access your wallet.
  # services.joinmarket.yieldgenerator.enable = true;

  # FIXME: Define your hostname.
  networking.hostName = "nix-bitcoin";
  time.timeZone = "UTC";

  # FIXME: Add your SSH pubkey
  services.openssh.enable = true;
  users.users.root = {
    openssh.authorizedKeys.keys = [ "" ];
  };

  # FIXME: add packages you need in your system
  environment.systemPackages = with pkgs; [
    vim
  ];

  # FIXME: Add custom options (like boot options, output of
  # nixos-generate-config, etc.):

  # If the hardened profile is imported above, we need to explicitly allow
  # user namespaces to enable sanboxed builds and services.
  security.allowUserNamespaces = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?

  # The nix-bitcoin release version that your config is compatible with.
  # When upgrading to a backwards-incompatible release, nix-bitcoin will display an
  # an error and provide hints for migrating your config to the new release.
  nix-bitcoin.configVersion = "0.0.18";
}
