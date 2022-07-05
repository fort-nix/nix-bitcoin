{ extraSources, krops }:

krops.lib.evalSource [({
  nixos-config.file = builtins.toFile "nixos-config" ''
    {
      imports = [
        ./configuration.nix
        <nix-bitcoin/modules/deployment/krops.nix>
      ];
    }
  '';

  "configuration.nix".file = toString ../configuration.nix;

  # Enable `useChecksum` for sources which might be located in the nix store
  # and which therefore might have static timestamps.

  nixpkgs.file = {
    path = toString <nixpkgs>;
    useChecksum = true;
    # TODO-EXTERNAL:
    # Work around symlink sync error on macOS/BSD
    # (https://github.com/NixOS/nixpkgs/issues/180046)
    # by excluding the single symlink that's present in nixpkgs.
    filters = [
      {
        type = "exclude";
        pattern = "/pkgs/development/libraries/readline/update-patch-set.sh";
      }
    ];
  };

  nix-bitcoin.file = {
    path = toString <nix-bitcoin>;
    useChecksum = true;
    filters = [{
      type = "exclude";
      pattern = ".git";
    }];
  };

  secrets.file = toString ../secrets;
} // extraSources)]
