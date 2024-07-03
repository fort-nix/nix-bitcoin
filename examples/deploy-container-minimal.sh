#!/usr/bin/env bash
set -euo pipefail

tmpDir=$(mktemp -d /tmp/nix-bitcoin-minimal-container.XXX)
trap 'rm -rf $tmpDir' EXIT

cd "${BASH_SOURCE[0]%/*}"

# Modify importable-configuration.nix to use the local <nix-bitcoin>
# source instead of fetchTarball
<importable-configuration.nix sed '
  s|nix-bitcoin = .*|nix-bitcoin = toString <nix-bitcoin>;|;
  s|system.extraDependencies = .*||
' > "$tmpDir/importable-configuration.nix"

cat > "$tmpDir/configuration.nix" <<EOF
  {
    imports = [ $tmpDir/importable-configuration.nix ];
    users.users.main = {
      isNormalUser = true;
      password = "a";
    };
    # When WAN is disabled, DNS bootstrapping slows down service startup by ~15 s
    # TODO-EXTERNAL:
    # When bitcoind is not fully synced, the offers plugin in clightning 24.05
    # crashes (see https://github.com/ElementsProject/lightning/issues/7378).
    services.clightning.extraConfig = ''
      disable-dns
      disable-plugin=offers
    '';
  }
EOF

./deploy-container.sh "$tmpDir/configuration.nix" "$@"
