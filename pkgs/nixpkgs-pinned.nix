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
    rev = "3d1a7716d7f1fccbd7d30ab3b2ed3db831f43bde";
    sha256 = "14r8qa6lnzp78c3amzi5r8n11l1kcxcx1gjhnc1kmn4indd43649";
  };
}
