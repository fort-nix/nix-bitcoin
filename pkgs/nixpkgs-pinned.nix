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
    rev = "5ff6700bb824a6d824fa021550a5596f6c3f64e7";
    sha256 = "16fiqgvq95d9cmq3ra6id0zyzmqqn7d7287y7igag7g53lrfbjqp";
  };
}
