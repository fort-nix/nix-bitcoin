{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-19.03";
    rev = "7936400662bc9379beb69855b0e0b7c0110e5f3c";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixpkgs-unstable";
    rev = "02bb5e35eae8a9e124411270a6790a08f68e905b";
  };
}

