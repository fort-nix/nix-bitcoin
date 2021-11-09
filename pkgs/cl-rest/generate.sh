#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq moreutils
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT

# Get/verify source tarball
version="0.5.2"
export GNUPGHOME=$TMPDIR
gpg --keyserver hkps://keyserver.ubuntu.com --recv-key 3E9BD4436C288039CA827A9200C9E2BC2E45666F
wget -P $TMPDIR https://github.com/Ride-The-Lightning/c-lightning-REST/archive/refs/tags/v${version}.tar.gz
wget -P $TMPDIR https://github.com/Ride-The-Lightning/c-lightning-REST/releases/download/v${version}/v${version}.tar.gz.asc
gpg --verify $TMPDIR/v${version}.tar.gz.asc $TMPDIR/v${version}.tar.gz
shasum=$(sha256sum $TMPDIR/v${version}.tar.gz | cut -d\  -f1)

# Run node2nix
mkdir $TMPDIR/package && tar xvf $TMPDIR/v${version}.tar.gz -C $TMPDIR/package --strip-components 1
cp pkg.json $TMPDIR/pkg.json
node2nix --nodejs-10 -i $TMPDIR/pkg.json -c composition.nix --no-copy-node-env

# Set node env import.
# The reason for not providing a custom node-env.nix file is the following:
# To be flakes-compatible, we have to locate the nixpgs source via `pkgs.path` instead of `<nixpkgs>`.
# This requires the `pkgs` variable which is available only in composition.nix, not in node-env.nix.
nodeEnvImport='import "${toString pkgs.path}/pkgs/development/node-packages/node-env.nix"'
sed -i "s|import ./node-env.nix|$nodeEnvImport|" composition.nix

# Use verified source in node-packages.nix
url="https://github.com/Ride-The-Lightning/c-lightning-REST/archive/refs/tags/v$version.tar.gz"
sed -i '/packageName = "c-lightning-rest";/!b;n;n;c\    src = fetchurl {\n      url = "'$url'";\n      sha256 = "'$shasum'";\n    };' node-packages.nix
