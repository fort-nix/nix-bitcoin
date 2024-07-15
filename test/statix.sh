#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/../helper/run-in-nix-env" "statix" "$@"

cd "${BASH_SOURCE[0]%/*}/.."

# Run statix over all nix files in this repo
statix check --format=errfmt .
