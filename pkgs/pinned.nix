let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
  nixpkgsStable = import nixpkgsPinned.nixpkgs { config = {}; overlays = []; };
  nixpkgsUnstable = import nixpkgsPinned.nixpkgs-unstable { config = {}; overlays = []; };
  nixBitcoinPkgsStable = import ./. { pkgs = nixpkgsStable; };
  nixBitcoinPkgsUnstable = import ./. { pkgs = nixpkgsUnstable; };
in
{
  inherit (nixpkgsUnstable)
    bitcoin
    bitcoind
    charge-lnd
    clightning
    lnd
    lndconnect
    nbxplorer
    btcpayserver
    electrs
    hwi
    lightning-loop
    lightning-pool;

  stable = nixBitcoinPkgsStable;
  unstable = nixBitcoinPkgsUnstable;
}
