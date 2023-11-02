# When using this file as the base for a real deployment,
# make sure to check all lines marked by 'FIXME:'

# This file is used by ./deploy.sh to deploy a container with
# age-encrypted secrets.

{
  inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";
  inputs.agenix.url = "github:ryantm/agenix";
  inputs.agenix.inputs.nixpkgs.follows = "nix-bitcoin/nixpkgs";

  inputs.flake-utils.follows = "nix-bitcoin/flake-utils";

  outputs = { self, nix-bitcoin, agenix, flake-utils }: {
    modules = {
      demoNode = { config, lib, ... }: {
        imports = [
          # TODO-EXTERNAL:
          # Set this to `agenix.nixosModules.default` when
          # https://github.com/ryantm/agenix/pull/126 is merged
          agenix.nixosModules.age
          nix-bitcoin.nixosModules.default
          (nix-bitcoin + "/modules/secrets/age.nix")
        ];

        # Use age-encrypted secrets
        nix-bitcoin.age = {
          enable = true;

          # The local secrets dir and its contents can be created with the
          # `generateAgeSecrets` flake package (defined below).
          # Use it like so:
          #   nix run .#generateAgeSecrets
          # and commit the newly created ./secrets dir afterwards.
          #
          # This script must be rerun when adding node services that
          # require new secrets.
          #
          # For a real-life example, see ./deploy.sh
          secretsSourceDir = ./secrets;

          # FIXME:
          # Set this to a public SSH host key of your node (preferably key type `ed25519`).
          # You can query host keys with command `ssh-keyscan <node address>`.
          # The keys defined here are used to age-encrypt the secrets.
          publicKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDoAaEMk8jMbg5MnvKDApWC6EpUHRJTzavy/wU2EtgtU"
          ];
        };

        # Enable services.
        # See ../configuration.nix for all available features.
        services.bitcoind.enable = true;
        #
        # See ../flakes/flake.nix for more settings useful for production nodes.


        # WARNING:
        # FIXME:
        # Remove the following `age.identityPaths` setting in a real deployment.
        # This copies a private key to the (publicly readable) Nix store,
        # which allows ./deploy.sh to start a age-based container in
        # a single deployment step.
        #
        # In a real deployment, just leave `age.identityPaths` undefined.
        # In this case, agenix uses the auto-generated SSH host key.
        age.identityPaths = [ ./host-key ];
      };
    };

    nixosConfigurations.demoNode = nix-bitcoin.inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ self.modules.demoNode ];
    };
  }
  // (nix-bitcoin.inputs.nixpkgs.lib.recursiveUpdate

    # Allow runnning this node as a container, used by ./deploy.sh
    (flake-utils.lib.eachSystem nix-bitcoin.lib.supportedSystems (system: {
      packages = {
        container = nix-bitcoin.inputs.extra-container.lib.buildContainers {
          inherit system;
          config.containers.nb-agenix = {
            privateNetwork = true;
            config.imports = [ self.modules.demoNode ];
          };
          # Set this when running on a NixOS container host with `system.stateVersion` <22.05
          # legacyInstallDirs = true;
        };
      };
    }))

    # This allows generating age-encrypted secrets on systems
    # that differ from the target node.
    # E.g. manage a `x86_64-linux` node from macOS (`aarch64-darwin`)
    (flake-utils.lib.eachDefaultSystem (system: {
      packages = {
        generateAgeSecrets = let
          nodeSystem = nix-bitcoin.inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ self.modules.demoNode ];
          };
        in
          nodeSystem.config.nix-bitcoin.age.generateSecretsScript;
      };
    }))
  );
}
