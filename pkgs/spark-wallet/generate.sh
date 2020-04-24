#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq moreutils
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT

# Get/verify spark-wallet-npm.tgz
version="0.2.14"
export GNUPGHOME=$TMPDIR
gpg --keyserver hkps://hkps.pool.sks-keyservers.net --recv-key FCF19B67866562F08A43AAD681F6104CD0F150FC
wget -P $TMPDIR https://github.com/shesek/spark-wallet/releases/download/v${version}/SHA256SUMS.asc
wget -P $TMPDIR https://github.com/shesek/spark-wallet/releases/download/v${version}/spark-wallet-${version}-npm.tgz
(cd $TMPDIR; gpg --verify $TMPDIR/SHA256SUMS.asc; sha256sum -c --ignore-missing $TMPDIR/SHA256SUMS.asc)
shasum=$(sha256sum $TMPDIR/spark-wallet-${version}-npm.tgz | cut -d\  -f1)

# Make qrcode-terminal a strict dependency so that node2nix includes it in the package derivation.
tar xvf $TMPDIR/spark-wallet-*-npm.tgz -C $TMPDIR
jq '.dependencies["qrcode-terminal"] = .optionalDependencies["qrcode-terminal"]' $TMPDIR/package/package.json | sponge $TMPDIR/package/package.json

# Run node2nix
cp pkg.json $TMPDIR/pkg.json
node2nix --nodejs-10 -i $TMPDIR/pkg.json -c composition.nix --no-copy-node-env --supplement-input supplement.json

# Use verified source in node-packages.nix
url="https://github.com/shesek/spark-wallet/releases/download/v$version/spark-wallet-$version-npm.tgz"
sed -i '/packageName = "spark-wallet";/!b;n;n;c\    src = fetchurl {\n      url = "'$url'";\n      sha256 = "'$shasum'";\n    };' node-packages.nix
