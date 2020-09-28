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
    rev = "5659cb448e9b615d642c5fe52779c2223e72f7eb";
    sha256 = "1ijwr9jlvdnvr1qqpfdm61nwd871sj4dam28pcv0pvnmp8ndylak";
  };
  nixpkgs-unstable = fetch {
    rev = "daaa0e33505082716beb52efefe3064f0332b521";
    sha256 = "15vprzpbllp9hy5md36ch1llzhxhd44d291kawcslgrzibw51f95";
  };
}
