{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "060bcd6df50bf2e61efe7b14b0458e83d72adc87";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixpkgs-unstable";
    rev = "6e5caa3f8ac48750233ef82a94825be238940825";
  };
}

