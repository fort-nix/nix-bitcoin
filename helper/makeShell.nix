{ configDir, shellVersion ? null, extraShellInitCmds ? (pkgs: "") }:
let
  inherit (pkgs) lib;
  nixpkgs = (import ../pkgs/nixpkgs-pinned.nix).nixpkgs;
  pkgs = import nixpkgs {};
  nbPkgs = import ../pkgs { inherit pkgs; };
  cfgDir = toString configDir;
  path = lib.optionalString pkgs.stdenv.isLinux ''
    export PATH="${lib.makeBinPath [ nbPkgs.extra-container ]}''${PATH:+:}$PATH"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "nix-bitcoin-environment";

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:nix-bitcoin=${toString ../.}:."
    ${path}
    export NIX_BITCOIN_EXAMPLES_DIR="${cfgDir}"

    # Set isInteractive=1 if
    # 1. stdout is a TTY, i.e. we're not piping the output
    # 2. the shell is interactive
    if [[ -t 1 && $- == *i* ]]; then isInteractive=1; else isInteractive=; fi

    help() {
        echo "nix-bitcoin path: ${toString ../.}"
        echo
        echo "Available commands"
        echo "=================="
        echo "deploy"
        echo "  Run krops-deploy and eval-config in parallel."
        echo "  This ensures that eval failures appear quickly when deploying."
        echo "  In this case, deployment is stopped."
        echo
        echo "krops-deploy"
        echo "  Deploy your node via krops"
        echo
        echo "eval-config"
        echo "  Evaluate your node system configuration"
        echo
        echo "generate-secrets"
        echo "  Create secrets required by your node configuration."
        echo "  Secrets are written to ./secrets/"
        echo "  This function is automatically called by krops-deploy."
        echo
        echo "update-nix-bitcoin"
        echo "  Fetch and use the latest version of nix-bitcoin"
    }
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
