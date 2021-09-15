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

  Note to NixOps users:
  - After updating `shell.nix`, secrets are no longer auto-generated
    when starting the shell. Please manually run shell command `generate-secrets`
    before deploying.
  - NixOps version 19.09 that shipped with nix-bitcoin is deprecated and is no longer
    available in the shell.
    Instead, you can add a current NixOps version to your shell PATH via `extraShellInitCmds`
    or migrate to the krops deployment method.
    See here for a migration guide:
    ${toString ../docs/nixops-krops-migration.md}
''
