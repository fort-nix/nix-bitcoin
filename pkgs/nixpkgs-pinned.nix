{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "680f9d7ea90dd0b48b51f29899c3110196b0e913";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixpkgs-unstable";
    rev = "796a8764ab85746f916e2cc8f6a9a5fc6d4d03ac";
  };
}

