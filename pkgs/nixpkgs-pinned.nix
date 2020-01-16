let
  fetch = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
{
  # To update, run ../helper/fetch-channel REV
  nixpkgs = fetch {
    rev = "d85e435b7bded2596d7b201bcd938c94d8a921c1";
    sha256 = "1msjm4kx1z73v444i1iybvmc7z0kfkbn9nzr21rn5yc4ql1jwf99";
  };
  nixpkgs-unstable = fetch {
    rev = "b0bbacb52134a7e731e549f4c0a7a2a39ca6b481";
    sha256 = "15ix4spjpdm6wni28camzjsmhz0gzk3cxhpsk035952plwdxhb67";
  };
}
