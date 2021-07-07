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
    rev = "036dc0c709650e0c833822307af801f576d67273";
    sha256 = "0pnrygs6xf7id63zi17pq5379hfppwbb5cfazhypcqz6l3dfk00g";
  };
}
