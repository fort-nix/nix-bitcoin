let
  fetch = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
rec {
  # To update, run ../helper/fetch-channel REV
  nixpkgs = nixpkgs-unstable;

  nixpkgs-unstable = fetch {
    rev = "1f77a4c8c74bbe896053994836790aa9bf6dc5ba";
    sha256 = "1j62nmzz3w33dplzf1xz1pg1pfkxii7lwdqmsxmc71cs9cm3s7n1";
  };
}
