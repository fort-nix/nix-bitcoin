{
  description = "A basic nix-bitcoin node";

  inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";

  outputs = { self, nix-bitcoin }: {

    nixosConfigurations.mynode = nix-bitcoin.inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-bitcoin.nixosModules.default

        # Optional:
        # Import the secure-node preset, an opinionated config to enhance security
        # and privacy.
        #
        # (nix-bitcoin + "/modules/presets/secure-node.nix")

        {
          # Automatically generate all secrets required by services.
          # The secrets are stored in /etc/nix-bitcoin-secrets
          nix-bitcoin.generateSecrets = true;

          # Enable services.
          # See ../configuration.nix for all available features.
          services.bitcoind.enable = true;

          # When using nix-bitcoin as part of a larger NixOS configuration, set the following to enable
          # interactive access to nix-bitcoin features (like bitcoin-cli) for your system's main user
          nix-bitcoin.operator = {
            enable = true;
            name = "main"; # Set this to your system's main user
          };

          # The system's main unprivileged user. This setting is usually part of your
          # existing NixOS configuration.
          users.users.main = {
            isNormalUser = true;
            password = "a";
          };

          # If you use a custom nixpkgs version for evaluating your system
          # (instead of `nix-bitcoin.inputs.nixpkgs` like in this example),
          # consider setting `useVersionLockedPkgs = true` to use the exact pkgs
          # versions for nix-bitcoin services that are tested by nix-bitcoin.
          # The downsides are increased evaluation times and increased system
          # closure size.
          #
          # nix-bitcoin.useVersionLockedPkgs = true;
        }
      ];
    };
  };
}
