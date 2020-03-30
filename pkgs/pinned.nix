let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
  unstable = import nixpkgsPinned.nixpkgs-unstable { config = {}; overlays = []; };
  nixBitcoinPkgsUnstable = import ./. { pkgs = unstable; };
in
{
  inherit (unstable)
    bitcoin
    bitcoind
    clightning
    lnd;
  inherit (nixBitcoinPkgsUnstable) electrs;
}
