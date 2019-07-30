{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-19.03";
    rev = "defa89ffaefc6425543089b81eb4c1053853ba37";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-unstable";
    rev = "239fffc90d792b5362a20ec1a009978de7b8f91a";
  };
}
