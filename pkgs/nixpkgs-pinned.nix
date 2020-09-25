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
    rev = "21d8e70a69f704a6ab971b2d8265d40cc7bb69b1";
    sha256 = "0d6ym23bzx8c4ani7lp3k9qmbv7j9bf15vfmiff0f5lbz326bdgi";
  };
  nixpkgs-unstable = fetch {
    rev = "1179840f9a88b8a548f4b11d1a03aa25a790c379";
    sha256 = "00jy37wj04bvh299xgal2iik2my9l0nq6cw50r1b2kdfrji8d563";
  };
}
