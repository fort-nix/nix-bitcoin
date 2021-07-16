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
    rev = "88e010dcb29ecf70a973c8d57ed175eadf7f42cf";
    sha256 = "0v6g32yw3cx2qg76idkccayap6lvnhkgnw70isy4vbjd88injmpv";
  };
}
