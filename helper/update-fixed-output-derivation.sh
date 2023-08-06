#!/usr/bin/env bash

set -euo pipefail

# The file that defines the derivation that should be updated
file=$1
# The name of the output of this flake that should be updated
flakeOutput=$2
# A pattern in a line preceding the hash that should be updated
patternPrecedingHash=$3

sed -i "/$patternPrecedingHash/,/hash/ s|hash = .*|hash = \"\";|" "$file"
# Display stderr and capture it. stdbuf is required to disable output buffering.
stderr=$(
    nix build --no-link -L ".#$flakeOutput" |&
      stdbuf -oL grep -v '\berror:.*failed to build$' |
      tee /dev/stderr || :
)
hash=$(echo "$stderr" | sed -nE 's/.*?\bgot: *?(sha256-.*)/\1/p')
if [[ ! $hash ]]; then
    echo
    echo "Error: No hash in build output."
    exit 1
fi
sed -i "/$patternPrecedingHash/,/hash/ s|hash = .*|hash = \"$hash\";|" "$file"
echo "(Note: The above hash mismatch message is not an error. It is part of the fetching process.)"
