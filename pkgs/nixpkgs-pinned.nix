{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-19.03";
    rev = "30a82bba734bc8d74fd291a0f7152809fb2cd037";
  };
  nixpkgs-unstable = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-unstable";
    rev = "83ba5afcc9682b52b39a9a958f730b966cc369c5";
  };
}
