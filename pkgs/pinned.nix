# This file is generated by ../helper/update-flake.nix
pkgs: pkgsUnstable:
{
  inherit (pkgs)
    bitcoin
    bitcoind
    bitcoind-knots
    charge-lnd
    clboss
    electrs
    elementsd
    extra-container
    fulcrum
    hwi
    lightning-pool
    lndconnect;

  inherit (pkgsUnstable)
    btcpayserver
    clightning
    lightning-loop
    lnd;

  inherit pkgs pkgsUnstable;
}
