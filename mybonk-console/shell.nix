let
  nix-bitcoin = toString (import ./nix-bitcoin-release.nix);
in
  import "${nix-bitcoin}/helper/makeShell.nix" {
    configDir = ./.;
    shellVersion = "0.0.51";
    # Set this to modify your shell
    # extraShellInitCmds = pkgs: ''<my bash code>'';
  }
