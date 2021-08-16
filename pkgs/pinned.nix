pkgs: pkgsUnstable:
{
  inherit (pkgsUnstable)
    bitcoin
    bitcoind
    charge-lnd
    clightning
    lnd
    lndconnect
    nbxplorer
    btcpayserver
    electrs
    elementsd
    hwi
    lightning-loop
    lightning-pool;

  inherit pkgs pkgsUnstable;
}
