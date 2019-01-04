let
  # Pin nixpkgs
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels";
    ref = "nixos-18.09";
    rev = "0396345b79436f54920f7eb651ab42acf2eb7973";
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
