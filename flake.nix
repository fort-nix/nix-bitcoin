{
  description = ''
    A collection of Nix packages and NixOS modules for easily
    installing full-featured Bitcoin nodes with an emphasis on security.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgsUnstable, flake-utils }:
    let
      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "armv7l-linux"
      ];
    in {
      lib = {
        mkNbPkgs = {
          system
          , pkgs ? nixpkgs.legacyPackages.${system}
          , pkgsUnstable ? nixpkgsUnstable.legacyPackages.${system}
        }:
          import ./pkgs { inherit pkgs pkgsUnstable; };
      };

      overlays.default = final: prev: let
        nbPkgs = self.lib.mkNbPkgs { inherit (final) system; pkgs = final; };
      in removeAttrs nbPkgs [ "pinned" "nixops19_09" "krops" ];

      nixosModules.default = { config, pkgs, lib, ... }: {
        imports = [ ./modules/modules.nix ];

        options = with lib; {
          nix-bitcoin.useVersionLockedPkgs = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Use the nixpkgs version locked by this flake for `nix-bitcoin.pkgs`.
              Only relevant if you are using a nixpkgs version for evaluating your system
              that differs from the one that is locked by this flake (via input `nixpkgs`).
              If this is the case, enabling this option may result in a more stable system
              because the nix-bitcoin services use the exact pkgs versions that are tested
              by nix-bitcoin.
              The downsides are increased evaluation times and increased system
              closure size.

              If `false`, the default system pkgs are used.
            '';
          };
        };

        config = {
          nix-bitcoin.pkgs =
            if config.nix-bitcoin.useVersionLockedPkgs
            then (self.lib.mkNbPkgs { inherit (config.nixpkgs) system; }).modulesPkgs
            else (self.lib.mkNbPkgs { inherit (pkgs) system; inherit pkgs; }).modulesPkgs;
        };
      };

      templates.default = {
        description = "Basic node template";
        path = ./examples/flakes;
      };

    } // (flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nbPkgs = self.lib.mkNbPkgs { inherit system pkgs; };
      in rec {
        packages = flake-utils.lib.flattenTree (removeAttrs nbPkgs [
          "pinned" "modulesPkgs" "nixops19_09" "krops" "generate-secrets" "netns-exec"
        ]) // {
          inherit (import ./examples/qemu-vm/minimal-vm.nix self pkgs system)
            # A simple demo VM.
            # See ./examples/flakes/flake.nix on how to use nix-bitcoin with flakes.
            runVM
            vm;
        };

        # Allow accessing the whole nested `nbPkgs` attrset (including `modulesPkgs`)
        # via this flake.
        # `packages` is not allowed to contain nested pkgs attrsets.
        legacyPackages = nbPkgs;

        apps = rec {
          default = vm;

          # Run a basic nix-bitcoin node in a VM
          vm = {
            type = "app";
            program = toString packages.runVM;
          };
        };
      }
    ));
}
