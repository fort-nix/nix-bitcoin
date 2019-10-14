let
  fetch = rev: builtins.fetchTarball "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
in
{
  nixpkgs = fetch "6420e2649fa9e267481fb78e602022dab9d1dcd1";
  nixpkgs-unstable = fetch "2436c27541b2f52deea3a4c1691216a02152e729";
}
