{
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "001b34abcb4d7f5cade707f7fd74fa27cbabb80b";
  };
  nixpkgs-unstable = builtins.fetchGit {
   url = "https://github.com/nixos/nixpkgs-channels";
   ref = "nixpkgs-unstable";
   rev = "8349329617ffa70164c5a16b049c2ef5f59416bd";
  };
}

