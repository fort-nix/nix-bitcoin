{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-19.03";
    rev = "6ec0970062c62935da71e6dbd3576bbbdcbfa10c";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-unstable";
    rev = "24debf74ef5c6e7799a5bc7edc4b2d6eae8e3c07";
  };
}

