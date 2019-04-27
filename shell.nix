let
  nixpkgs = (import ./pkgs/nixpkgs-pinned.nix).nixpkgs;
in
with import nixpkgs { };

stdenv.mkDerivation rec {
  name = "nix-bitcoin-environment";

  buildInputs = [ pkgs.nixops pkgs.figlet pkgs.apg pkgs.openssl ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:."
    # ssh-agent and nixops don't play well together (see
    # https://github.com/NixOS/nixops/issues/256). I'm getting `Received disconnect
    # from 10.1.1.200 port 22:2: Too many authentication failures` if I have a few
    # keys already added to my ssh-agent.
    export SSH_AUTH_SOCK=""
    figlet "nix-bitcoin"
    ./secrets/generate_secrets.sh
  '';
}
