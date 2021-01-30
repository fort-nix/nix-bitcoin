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
    rev = "891f607d5301d6730cb1f9dcf3618bcb1ab7f10e";
    sha256 = "1cr39f0sbr0h5d83dv1q34mcpwnkwwbdk5fqlyqp2mnxghzwssng";
  };
}
