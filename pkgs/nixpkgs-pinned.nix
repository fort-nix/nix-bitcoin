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
    rev = "93c2261684ea8c65606d7167b5d52b8da7d7778a";
    sha256 = "1vjh0np1rlirbhhj9b2d0zhrqdmiji5svxh9baqq7r3680af1iif";
  };
  nixpkgs-unstable = fetch {
    rev = "5ff6700bb824a6d824fa021550a5596f6c3f64e7";
    sha256 = "16fiqgvq95d9cmq3ra6id0zyzmqqn7d7287y7igag7g53lrfbjqp";
  };
}
