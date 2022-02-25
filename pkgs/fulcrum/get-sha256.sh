#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils git gnupg nix_2_4
set -euo pipefail

version="bcccf76f5fa8570d87a7077caddb86ee504fd1d8"

# Fetch release and GPG-verify the content hash
tmpdir=$(mktemp -d /tmp/fulcrum-verify-gpg.XXX)
repo=$tmpdir/repo
#trap "rm -rf $tmpdir" EXIT
git clone https://github.com/cculianu/Fulcrum $repo
git -C $repo checkout $version
export GNUPGHOME=$tmpdir
# Fetch cculianu's key
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys D465135F97D0047E18E99DC321810A542031C02C
echo
echo "Verifying commit"
git -C $repo verify-commit ${version}
rm -rf $repo/.git
hash=$(nix hash path $repo)
rm -rf $tmpdir
echo $hash
