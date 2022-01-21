#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq moreutils gnused
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT

version="0.3.1"
repo=https://github.com/shesek/spark-wallet

# Fetch and verify source tarball
file=spark-wallet-${version}-npm.tgz
url=$repo/releases/download/v$version/$file
export GNUPGHOME=$TMPDIR
gpg --keyserver hkps://keyserver.ubuntu.com --recv-key FCF19B67866562F08A43AAD681F6104CD0F150FC
wget -P $TMPDIR $url
wget -P $TMPDIR $repo/releases/download/v$version/SHA256SUMS.asc
gpg --verify $TMPDIR/SHA256SUMS.asc
(cd $TMPDIR; sha256sum --check --ignore-missing SHA256SUMS.asc)
hash=$(nix hash file $TMPDIR/$file)

# Extract source
src=$TMPDIR/src
mkdir $src
tar xvf $TMPDIR/$file -C $src --strip-components 1 >/dev/null

# Make qrcode-terminal a strict dependency so that node2nix includes it in the package derivation.
jq '.dependencies["qrcode-terminal"] = .optionalDependencies["qrcode-terminal"]' $src/package.json | sponge $src/package.json

# Generate nix pkg
node2nix \
  --nodejs-12 \
  --input $src/package.json \
  --lock $src/npm-shrinkwrap.json \
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

sed -i "
  # Use the verified package src
  s|src = .*/src;|src = ${fetchurl//$'\n'/\\n}|

  # github: use HTTPS instead of SSH, which requires user authentication
  s|git+ssh://git@|https://|
  s|ssh://git@|https://|
  s|\.git#|#|
" node-packages.nix
