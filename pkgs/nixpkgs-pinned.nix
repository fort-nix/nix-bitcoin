{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-19.03";
    rev = "c8124c121522134a1b60ccfcfdd3768049d76098";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-unstable";
    rev = "c7bcd4277cc9a656207b636dbc62fef21dc64c78";
  };
}

