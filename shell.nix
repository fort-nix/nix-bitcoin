let
  # Pin nixpkgs
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "001b34abcb4d7f5cade707f7fd74fa27cbabb80b";
  };
in
with import nixpkgs { };

stdenv.mkDerivation rec {
  name = "nix-bitcoin-environment";

  buildInputs = [ pkgs.nixops pkgs.figlet pkgs.apg ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:."
    figlet "nix-bitcoin"
    ./secrets/generate_secrets.sh
  '';
}
