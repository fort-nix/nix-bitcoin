let
  fetch = rev: builtins.fetchTarball "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
in
{
  nixpkgs = fetch "e6ad5e75f3bfaab5e7b7f0f128bf13d534879e65";
  nixpkgs-unstable = fetch "765a71f15025ce78024bae3dc4a92bd2be3a8fbf";
}
