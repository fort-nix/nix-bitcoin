#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq moreutils
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT

# Get/verify spark-wallet-npm.tgz
version="0.3.1"
export GNUPGHOME=$TMPDIR
gpg --keyserver hkps://keyserver.ubuntu.com --recv-key FCF19B67866562F08A43AAD681F6104CD0F150FC
wget -P $TMPDIR https://github.com/shesek/spark-wallet/releases/download/v${version}/SHA256SUMS.asc
wget -P $TMPDIR https://github.com/shesek/spark-wallet/releases/download/v${version}/spark-wallet-${version}-npm.tgz
(cd $TMPDIR; gpg --verify $TMPDIR/SHA256SUMS.asc; sha256sum -c --ignore-missing $TMPDIR/SHA256SUMS.asc)
shasum=$(sha256sum $TMPDIR/spark-wallet-${version}-npm.tgz | cut -d\  -f1)

# Make qrcode-terminal a strict dependency so that node2nix includes it in the package derivation.
tar xvf $TMPDIR/spark-wallet-*-npm.tgz -C $TMPDIR
jq '.dependencies["qrcode-terminal"] = .optionalDependencies["qrcode-terminal"]' $TMPDIR/package/package.json | sponge $TMPDIR/package/package.json

# Run node2nix
cp pkg.json $TMPDIR/pkg.json
node2nix --nodejs-10 -i $TMPDIR/pkg.json -c composition.nix --no-copy-node-env

# Set node env import.
# The reason for not providing a custom node-env.nix file is the following:
# To be flakes-compatible, we have to locate the nixpgs source via `pkgs.path` instead of `<nixpkgs>`.
# This requires the `pkgs` variable which is available only in composition.nix, not in node-env.nix.
nodeEnvImport='import "${toString pkgs.path}/pkgs/development/node-packages/node-env.nix"'
sed -i "s|import ./node-env.nix|$nodeEnvImport|" composition.nix

# Use verified source in node-packages.nix
url="https://github.com/shesek/spark-wallet/releases/download/v$version/spark-wallet-$version-npm.tgz"
sed -i '/packageName = "spark-wallet";/!b;n;n;c\    src = fetchurl {\n      url = "'$url'";\n      sha256 = "'$shasum'";\n    };' node-packages.nix
