#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq gnused
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT

version="0.13.0"
repo=https://github.com/Ride-The-Lightning/RTL

# Fetch and verify source tarball
file=v${version}.tar.gz
url=$repo/archive/refs/tags/$file
export GNUPGHOME=$TMPDIR
gpg --keyserver hkps://keyserver.ubuntu.com --recv-key 3E9BD4436C288039CA827A9200C9E2BC2E45666F
wget -P $TMPDIR $url
wget -P $TMPDIR $repo/releases/download/v${version}/$file.asc
gpg --verify $TMPDIR/$file.asc $TMPDIR/$file
hash=$(nix hash file $TMPDIR/$file)

# Extract source
src=$TMPDIR/src
mkdir $src
tar xvf $TMPDIR/$file -C $src --strip-components 1 >/dev/null

# Generate nix pkg
node2nix \
  --input $src/package.json \
  --lock $src/package-lock.json \
  --composition composition.nix \
  --no-copy-node-env

# Use node-env.nix from nixpkgs
nodeEnvImport='import "${toString pkgs.path}/pkgs/development/node-packages/node-env.nix"'
sed -i "s|import ./node-env.nix|$nodeEnvImport|" composition.nix

# Use the verified package src
read -d '' fetchurl <<EOF || :
fetchurl {
      url = "$url";
      hash = "$hash";
    };
EOF
sed -i "s|src = .*/src;|src = ${fetchurl//$'\n'/\\n}|" node-packages.nix
