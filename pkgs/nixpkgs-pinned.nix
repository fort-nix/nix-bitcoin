{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "060bcd6df50bf2e61efe7b14b0458e83d72adc87";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixpkgs-unstable";
    rev = "9b3e5a3aab728e7cea2da12b6db300136604be3a";
  };
}

