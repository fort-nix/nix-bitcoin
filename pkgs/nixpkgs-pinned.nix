let
  fetch = rev: builtins.fetchTarball "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
in
{
  nixpkgs = fetch "27a5ddcf747fb2bb81ea9c63f63f2eb3eec7a2ec";
  nixpkgs-unstable = fetch "4cd2cb43fb3a87f48c1e10bb65aee99d8f24cb9d";
}
