{ configDir, extraShellInitCmds ? (pkgs: "") }:
let
  nixpkgs = (import ../pkgs/nixpkgs-pinned.nix).nixpkgs;
  pkgs = import nixpkgs {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  cfgDir = toString configDir;
in
with pkgs;
stdenv.mkDerivation rec {
  name = "nix-bitcoin-environment";

  path = lib.makeBinPath [ nbPkgs.extra-container ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:nix-bitcoin=${toString ../.}:."
    export PATH="${path}''${PATH:+:}$PATH"

    export NIX_BITCOIN_EXAMPLES_DIR="${cfgDir}"

    fetch-release() {
      ${toString ./fetch-release}
    }

    generate-secrets() {(
      set -euo pipefail
      genSecrets=$(nix-build --no-out-link -I nixos-config="${cfgDir}/configuration.nix" \
                   '<nixpkgs/nixos>' -A config.nix-bitcoin.generateSecretsScript)
      mkdir -p "${cfgDir}/secrets"
      (cd "${cfgDir}/secrets"; $genSecrets)
    )}

    krops-deploy() {(
      set -euo pipefail
      generate-secrets
      # Ensure strict permissions on secrets/ directory before rsyncing it to
      # the target machine
      chmod 700 "${cfgDir}/secrets"
      $(nix-build --no-out-link "${cfgDir}/krops/deploy.nix")
    )}

    # Print logo if
    # 1. stdout is a TTY, i.e. we're not piping the output
    # 2. the shell is interactive
    if [[ -t 1 && $- == *i* ]]; then
      ${figlet}/bin/figlet "nix-bitcoin"
    fi

    # Don't run this hook when another nix-shell is run inside this shell
    unset shellHook

    ${extraShellInitCmds pkgs}
  '';
}
