{
  # The modules are topologically sorted by their dependencies.
  # This means that modules only depend on modules higher in the list
  # (unless otherwise noted).
  imports = [
    # Core modules
    ./nix-bitcoin.nix
    ./secrets/secrets.nix
    ./operator.nix

    # Main features
    ./bitcoind.nix
    ./clightning.nix
    ./clightning-plugins
    ./spark-wallet.nix
    ./lnd.nix
    ./lnd-rest-onion-service.nix # Requires onion-addresses.nix
    ./lightning-loop.nix
    ./lightning-pool.nix
    ./charge-lnd.nix
    ./btcpayserver.nix
    ./electrs.nix
    ./squeaknode.nix
    ./liquid.nix
    ./joinmarket.nix
    ./joinmarket-ob-watcher.nix
    ./hardware-wallets.nix
    ./recurring-donations.nix

    # Support features
    ./versioning.nix
    ./security.nix
    ./onion-addresses.nix
    ./onion-services.nix
    ./netns-isolation.nix
    ./nodeinfo.nix
    ./backups.nix
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];
}
