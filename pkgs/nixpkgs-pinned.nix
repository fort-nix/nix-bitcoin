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
    rev = "e34208e10033315fddf6909d3ff68e2d3cf48a23";
    sha256 = "0ngkx5ny7bschmiwc5q9yza8fdwlc3zg47avsywwp8yn96k2cpmg";
  };
  nixpkgs-unstable = fetch {
    rev = "296793637b22bdb4d23b479879eba0a71c132a66";
    sha256 = "0j09yih9693w5vjx64ikfxyja1ha7pisygrwrpg3wfz3sssglg69";
  };
}
