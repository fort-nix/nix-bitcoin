throw ''
  Please update the `shell.nix` of your node configuration.

  To update, do the following:
  1. Switch to the directory containing your `configuration.nix` and `shell.nix`.
  2. Run the following Bash expression (Warning: This overwrites your `shell.nix`):

  # Only update nix-bitcoin-release.nix if it contains a release hash
  if grep -q sha256 nix-bitcoin-release.nix; then
    ${toString ../helper/fetch-release} > nix-bitcoin-release.nix && cp ${toString ../examples/shell.nix} .
  else
    cp ${toString ../examples/shell.nix} .
  fi
''
