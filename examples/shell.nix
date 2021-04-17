let
  # This is either a path to a local nix-bitcoin source or an attribute set to
  # be used as the fetchurl argument.
  nix-bitcoin-release = import ./nix-bitcoin-release.nix;

  nix-bitcoin-path =
    if builtins.isAttrs nix-bitcoin-release then nix-bitcoin-unpacked
    else nix-bitcoin-release;

  nixpkgs-path = (import "${toString nix-bitcoin-path}/pkgs/nixpkgs-pinned.nix").nixpkgs;
  pkgs = import nixpkgs-path {};
  nix-bitcoin = pkgs.callPackage nix-bitcoin-path {};

  nix-bitcoin-unpacked = (import <nixpkgs> {}).runCommand "nix-bitcoin-src" {} ''
    mkdir $out; tar xf ${builtins.fetchurl nix-bitcoin-release} -C $out
  '';
in
with pkgs;
stdenv.mkDerivation rec {
  name = "nix-bitcoin-environment";

  path = lib.makeBinPath [ nix-bitcoin.extra-container ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs-path}:nix-bitcoin=${toString nix-bitcoin-path}:."
    export PATH="${path}''${PATH:+:}$PATH"

    export NIX_BITCOIN_EXAMPLES_DIR="${toString ./.}"

    fetch-release() {
      ${toString nix-bitcoin-path}/helper/fetch-release
    }

    krops-eval() {
      nix-instantiate -- --expr '
        (import <nixpkgs/nixos> {
          configuration = ./krops/krops-configuration.nix;
        }).system
      ' 2> >(grep -v "the result might be removed by the garbage collector") > /dev/null
    }

    krops-deploy() {
      krops-eval
      # Ensure strict permissions on secrets/ directory before rsyncing it to
      # the target machine
      chmod 700 ${toString ./secrets}
      $(nix-build --no-out-link ${toString ./krops/deploy.nix})
    }

    # Print logo if
    # 1. stdout is a TTY, i.e. we're not piping the output
    # 2. the shell is interactive
    if [[ -t 1 && $- == *i* ]]; then
      ${figlet}/bin/figlet "nix-bitcoin"
    fi

    (mkdir -p secrets; cd secrets; env -i ${nix-bitcoin.generate-secrets})

    # Don't run this hook when another nix-shell is run inside this shell
    unset shellHook
  '';
}
