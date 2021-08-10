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
    rev = "359e6542e1d41eb18df55c82bdb08bf738fae2cf";
    sha256 = "05v28njaas9l26ibc6vy6imvy7grbkli32bmv0n32x6x9cf68gf9";
  };
  nixpkgs-unstable = fetch {
    rev = "16105403bdd843540cbef9c63fc0f16c1c6eaa70";
    sha256 = "0sl6hsxlh14kcs38jcra908nvi5hd8p8hlim3lbra55lz0kd9rcl";
  };
}
