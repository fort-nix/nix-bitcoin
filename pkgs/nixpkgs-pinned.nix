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
    rev = "296793637b22bdb4d23b479879eba0a71c132a66";
    sha256 = "0j09yih9693w5vjx64ikfxyja1ha7pisygrwrpg3wfz3sssglg69";
  };
}
