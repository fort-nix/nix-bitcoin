{
  description = ''
    nix-bitcoin is a collection of Nix packages and NixOS modules for easily
    installing full-featured Bitcoin nodes with an emphasis on security.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
    unstable.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, unstable, flake-utils } @ args: 
    with flake-utils.lib;
    (eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: { unstable = import unstable { inherit system; }; })
          ];
        };
      in {
        packages = flattenTree (import ./pkgs { inherit pkgs; });
        nixosConfigurations = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              imports = [
                ./modules/presets/secure-node.nix
                ./modules/presets/hardened.nix
              ];
              boot.isContainer = true;
              nixpkgs.pkgs = pkgs;

              system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

              networking.hostName = "nix-bitcoin";

              services.openssh.enable = true;
              users.users.root.initialPassword = "toor";

              nix-bitcoin.configVersion = "0.0.30";
            }
            ./modules/secrets/generate-secrets.nix
          ];
        };
      }
    )) // { nixosModules = import ./modules; };
}
