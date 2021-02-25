let
  fetch = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
{
  # To update, run ../helper/fetch-channel REV
  nixpkgs = fetch {
    rev = "6fbc72a353a1b0ae4f5b48cae111bfb1a4d3a529";
    sha256 = "0aj4xfkwk8gf96ypjp0rcap3hxrqg5qdwgwgx55zk0mlvq9z3h68";
  };
  nixpkgs-unstable = fetch {
    rev = "c7d0dbe094c988209edac801eb2a0cc21aa498d8";
    sha256 = "1rwjfjwwaic56n778fvrmv1s1vzw565gqywrpqv72zrrzmavhyrx";
  };
}
