{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "222950952f15f6b1e9f036b80440b597f23e652d";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixpkgs-unstable";
    rev = "0c0954781e257b8b0dc49341795a2fe7d96945a3";
  };
}

