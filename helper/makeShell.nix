{ configDir, shellVersion ? null, extraShellInitCmds ? (pkgs: "") }:
let
  inherit (pkgs) lib;
  nixpkgs = (import ../pkgs/nixpkgs-pinned.nix).nixpkgs;
  pkgs = import nixpkgs {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  cfgDir = toString configDir;
  path = lib.optionalString pkgs.stdenv.isLinux ''
    export PATH="${lib.makeBinPath [ nbPkgs.pinned.extra-container ]}''${PATH:+:}$PATH"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "nix-bitcoin-environment";

  helpMessage = ''
    nix-bitcoin path: ${toString ../.}

    Available commands
    ==================
    deploy
      Run krops-deploy and eval-config in parallel.
      This ensures that eval failures appear quickly when deploying.
      In this case, deployment is stopped.

    krops-deploy
      Deploy your node via krops

    eval-config
      Evaluate your node system configuration

    generate-secrets
      Create secrets required by your node configuration.
      Secrets are written to ./secrets/
      This function is automatically called by krops-deploy.

    update-nix-bitcoin
      Fetch and use the latest version of nix-bitcoin
  '';

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:nix-bitcoin=${toString ../.}:."
    ${path}
    export NIX_BITCOIN_EXAMPLES_DIR="${cfgDir}"

    # Set isInteractive=1 if
    # 1. stdout is a TTY, i.e. we're not piping the output
    # 2. the shell is interactive
    if [[ -t 1 && $- == *i* ]]; then isInteractive=1; else isInteractive=; fi

    # Make this a non-environment var
    export -n helpMessage

    help() { echo "$helpMessage"; }
    h() { help; }

    fetch-release() {
      ${toString ./fetch-release}
    }

    update-nix-bitcoin() {(
      set -euo pipefail
      releaseFile="${cfgDir}/nix-bitcoin-release.nix"
      current=$(cat "$releaseFile" 2>/dev/null || true)
      new=$(fetch-release)
      if [[ $new == $current ]]; then
        echo "nix-bitcoin-release.nix already contains the latest release"
      else
        echo "$new" > "$releaseFile"
        echo "Updated nix-bitcoin-release.nix"
        if [[ $isInteractive ]]; then
          exec nix-shell
        fi
      fi
    )}

    generate-secrets() {(
      set -euo pipefail
      genSecrets=$(nix-build --no-out-link -I nixos-config="${cfgDir}/configuration.nix" \
                   '<nixpkgs/nixos>' -A config.nix-bitcoin.generateSecretsScript)
      mkdir -p "${cfgDir}/secrets"
      (cd "${cfgDir}/secrets"; $genSecrets)
    )}

    deploy() {(
      set -euo pipefail
      krops-deploy &
      kropsPid=$!
      if eval-config; then
        wait $kropsPid
      else
        # Kill all subprocesses
        kill $(pidClosure $kropsPid)
        return 1
      fi
    )}

    krops-deploy() {(
      set -euo pipefail
      generate-secrets
      # Ensure strict permissions on secrets/ directory before rsyncing it to
      # the target machine
      chmod 700 "${cfgDir}/secrets"
      $(nix-build --no-out-link "${cfgDir}/krops/deploy.nix")
    )}

    eval-config() {
      NIXOS_CONFIG="${cfgDir}/krops/krops-configuration.nix" nix eval --raw -f ${nixpkgs}/nixos system.outPath
      echo
    }

    pidClosure() {
      echo "$1"
      for pid in $(ps -o pid= --ppid "$1"); do
        pidClosure "$pid"
      done
    }

    if [[ $isInteractive ]]; then
      ${pkgs.figlet}/bin/figlet "nix-bitcoin"
      echo 'Enter "h" or "help" for documentation.'
    fi

    # Don't run this hook when another nix-shell is run inside this shell
    unset shellHook

    ${extraShellInitCmds pkgs}
  '';
}
