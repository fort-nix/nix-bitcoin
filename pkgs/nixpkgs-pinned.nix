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
    rev = "c2c5dcc00b05f0f6007d7a997dc9d90aefb49f28";
    sha256 = "1sjy9b1jh7k4bhww42zyjjim4c1nn8r4fdbqmyqy4hjyfrh9z6jc";
  };
  nixpkgs-unstable = fetch {
    rev = "ea79a830dcf9c0059656da7f52835d2663d5c436";
    sha256 = "0vqnfh99358v9ym5z9i3dsfy0l4xxgh9hr278pi1y11gdl092014";
  };
}
