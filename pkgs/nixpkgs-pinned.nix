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
    rev = "07e66484e679d0e28533543f762be20d6d425b66";
    sha256 = "1d3n1yfp9xhl7nh377sp2wwnh0gscislg6gzj8sgdq169d18lgsg";
  };
  nixpkgs-unstable = fetch {
    rev = "c1966522d7d5fa54db068140d212cba18731dd98";
    sha256 = "104481nxv0hi1rk3g0fjzyki1668p4b46bz0j3lsqv5gv1nm43vm";
  };
}
