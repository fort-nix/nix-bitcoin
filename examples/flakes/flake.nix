# This is a system configuration template that uses nix-bitcoin.
#
# You can adapt this to an existing system flake by copying the parts
# relevant to nix-bitcoin.
#
# Make sure to check and edit all lines marked by 'FIXME:'

{
  description = "A basic nix-bitcoin node";

  inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";
  # You can also use a version branch to track a specific NixOS release
  # inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin/nixos-24.05";

  inputs.nixpkgs.follows = "nix-bitcoin/nixpkgs";
  inputs.nixpkgs-unstable.follows = "nix-bitcoin/nixpkgs-unstable";

  outputs = { self, nixpkgs, nix-bitcoin, ... }: {

    nixosConfigurations.mynode = nixpkgs.lib.nixosSystem {
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

          # Enable some services.
          # See ../configuration.nix for all available features.
          services.bitcoind.enable = true;
          services.clightning.enable = true;

          # When using nix-bitcoin as part of a larger NixOS configuration, set the following to enable
          # interactive access to nix-bitcoin features (like bitcoin-cli) for your system's main user
          nix-bitcoin.operator = {
            enable = true;
            # FIXME: Set this to your system's main user
            name = "main";
          };

          # The system's main unprivileged user.
          # In an existing NixOS configuration, this setting is usually already defined.
          users.users.main = {
            isNormalUser = true;
            # FIXME: This is unsafe. Use `hashedpassword` or `passwordFile` instead in a real
            # deployment: https://search.nixos.org/options?show=users.users.%3Cname%3E.hashedPassword
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
