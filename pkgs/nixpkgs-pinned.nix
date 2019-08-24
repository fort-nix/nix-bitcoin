{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-19.03";
    rev = "e6ad5e75f3bfaab5e7b7f0f128bf13d534879e65";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-unstable";
    rev = "765a71f15025ce78024bae3dc4a92bd2be3a8fbf";
  };
}
