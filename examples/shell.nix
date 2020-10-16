let
  # This is either a path to a local nix-bitcoin source or an attribute set to
  # be used as the fetchurl argument.
  nix-bitcoin-release = import ./nix-bitcoin-release.nix;

  nix-bitcoin-path =
    if builtins.isAttrs nix-bitcoin-release then nix-bitcoin-unpacked
    else nix-bitcoin-release;

  nixpkgs-path = (import "${toString nix-bitcoin-path}/pkgs/nixpkgs-pinned.nix").nixpkgs;
  nixpkgs = import nixpkgs-path {};
  nix-bitcoin = nixpkgs.callPackage nix-bitcoin-path {};

  nix-bitcoin-unpacked = (import <nixpkgs> {}).runCommand "nix-bitcoin-src" {} ''
    mkdir $out; tar xf ${builtins.fetchurl nix-bitcoin-release} -C $out
  '';
in
with nixpkgs;

stdenv.mkDerivation rec {
  name = "nix-bitcoin-environment";

  buildInputs = [ nix-bitcoin.nixops19_09 nix-bitcoin.extra-container figlet ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs-path}:nix-bitcoin=${toString nix-bitcoin-path}:."
    alias fetch-release="${toString nix-bitcoin-path}/helper/fetch-release"

    # ssh-agent and nixops don't play well together (see
    # https://github.com/NixOS/nixops/issues/256). I'm getting `Received disconnect
    # from 10.1.1.200 port 22:2: Too many authentication failures` if I have a few
    # keys already added to my ssh-agent.
    export SSH_AUTH_SOCK=""

    figlet "nix-bitcoin"
    (mkdir -p secrets; cd secrets; ${nix-bitcoin.generate-secrets})

    # Don't run this hook when another nix-shell is run inside this shell
    unset shellHook
  '';
}
