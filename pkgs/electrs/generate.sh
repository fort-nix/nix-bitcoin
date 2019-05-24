#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg dirmngr
set -e

# Creating temporary directory
echo "Creating temporary directory"
DIR="$(mktemp -d)"
cd $DIR
git clone https://github.com/romanz/electrs

# Checking out latest release
echo "Checking out latest release"
cd electrs
latesttagelectrs=$(git describe --tags `git rev-list --tags --max-count=1`)
git checkout ${latesttagelectrs}
echo "Latest release is ${latesttagelectrs}"

# Optional GPG Verification
read -p "Do you want to import Roman Zeyde's PGP Key (46917CBB)? [yN]" -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo "Getting Roman Zeyde's PGP key"
gpg --recv-keys 15C8C3574AE4F1E25F3F35C587CAE5FA46917CBB
echo "Verifying latest release"
git verify-tag ${latesttagelectrs}
fi

echo "Generating crate2nix expression"
git clone https://github.com/kolloch/crate2nix ../crate2nix
cd ../crate2nix
git checkout e311fc6f88b61e1eda85e8c588e7c23dea03b532 # latest commit that works
cd ../electrs
nix-shell -v ../crate2nix/shell.nix --run "crate2nix generate"

echo "Fixing nix expression"
sed -i 's/(path+file.*)/(registry+https:\/\/github.com\/romanz\/electrs)/g' default.nix
sed -i '/crateName = "electrs";/i\        name = "electrs-${version}";' default.nix
sed -i 's/src = (builtins.filterSource sourceFilter .\/.);/sha256 = "<insert correct hash here>";/g' default.nix
# @jb55's fixes from https://github.com/jb55/electrs/commit/e3bed69c17dac1af1be34d18e5be2c815c20838c
sed -i '/lib? pkgs.lib/a\  llvmPackages ? pkgs.llvmPackages,' default.nix
sed -i 's/resolvedDefaultFeatures = \[ "bzip2" "default" "lz4" "snappy" "static" "zlib" "zstd" \]/resolvedDefaultFeatures = \[ "bzip2" "default" "lz4" "snappy" "static" "zlib" \]/g' default.nix
sed -i '/crateName = "librocksdb-sys";/a\\n        enableParallelBuilding = true;\n        buildInputs = [ pkgs.clang ];\n        LIBCLANG_PATH = "${llvmPackages.libclang}/lib";\n' default.nix
sed -i 's/"default" = \[ "snappy" "lz4" "zstd" "zlib" "bzip2" \];/"default" = \[ "snappy" "zstd" "zlib" "bzip2" \];/g' default.nix
echo "Done. You now have your pkgs/electrs/default.nix expression in $DIR/electrs/default.nix. Just replace the electrs sha256 and you'll be good to go."
