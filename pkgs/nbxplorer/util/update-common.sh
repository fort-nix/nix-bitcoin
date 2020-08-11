#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl jq common-updater-scripts dotnet-sdk_3
set -euo pipefail

# This script uses the following env vars:
# getVersionFromTags
# onlyCreateDeps

pkgName=$1
depsFile=$2

: ${getVersionFromTags:=}
: ${onlyCreateDeps:=}

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
nbPkgs=$(realpath "$scriptDir"/../..)

evalNbPkgs() {
  nix eval --raw "(with import \"$nbPkgs\" {}; $1)"
}

getRepo() {
  url=$(evalNbPkgs $pkgName.src.meta.homepage)
  echo $(basename $(dirname $url))/$(basename $url)
}

getLatestVersionTag() {
  unstable=$(nix eval --raw "(import \"$nbPkgs/nixpkgs-pinned.nix\").nixpkgs-unstable")
  $unstable/pkgs/common-updater/scripts/list-git-tags https://github.com/$(getRepo) 2>/dev/null \
    | sort -V | tail -1 | sed 's|^v||'
}

if [[ ! $onlyCreateDeps ]]; then
  oldVersion=$(evalNbPkgs "$pkgName.version")
  if [[ $getVersionFromTags ]]; then
    newVersion=$(getLatestVersionTag)
  else
    newVersion=$(curl -s "https://api.github.com/repos/$(getRepo)/releases" | jq -r '.[0].name')
  fi

  if [[ $newVersion == $oldVersion ]]; then
    echo "$pkgName is up to date: $newVersion"
  else
    echo "Please manually update $pkgName: $oldVersion -> $newVersion"
  fi
fi

echo "Creating deps.nix"
storeSrc="$(nix-build "$nbPkgs" -A $pkgName.src --no-out-link)"
. "$scriptDir"/create-deps.sh "$storeSrc" "$depsFile"
