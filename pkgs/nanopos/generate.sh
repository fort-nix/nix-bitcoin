#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix
exec node2nix --nodejs-10 -i pkg.json -c composition.nix --no-copy-node-env --supplement-input supplement.json
