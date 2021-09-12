let
  nix-bitcoin = toString (import ./nix-bitcoin-release.nix);
in
  import "${nix-bitcoin}/helper/makeShell.nix" {
    configDir = ./.;
    # Set this to modify your shell
    # extraShellInitCmds = (pkgs: ''<my bash code>'');
  }
