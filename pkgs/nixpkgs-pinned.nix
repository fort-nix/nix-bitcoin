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
    rev = "a9226f2b3a52fcbbc5587d2fa030729e714f40fe";
    sha256 = "0xlzkymfrkj7z7b6hwliq2zn6pbjw08zka0qyv5bbnkhnv16x1dh";
  };
  nixpkgs-unstable = fetch {
    rev = "84d74ae9c9cbed73274b8e4e00be14688ffc93fe";
    sha256 = "0ww70kl08rpcsxb9xdx8m48vz41dpss4hh3vvsmswll35l158x0v";
  };
}
