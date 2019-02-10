{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "5225d4bf0193b51cfb1a200faa4ae50958f98c62";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixpkgs-unstable";
    rev = "2b2820df94fd4a78cf03fb17b8e4c04d7f7395f7";
  };
}

