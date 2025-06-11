# See how this flake is used in ./usage.sh

# See also:
# https://github.com/erikarvstedt/extra-container
# https://github.com/erikarvstedt/extra-container/blob/master/examples/flake
# Container-related NixOS options
# https://search.nixos.org/options?channel=unstable&query=containers.%3Cname%3E

{
  description = "A basic nix-bitcoin container node";

  inputs = {
    nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";
    # You can also use a version branch to track a specific NixOS release
    # nix-bitcoin.url = "github:fort-nix/nix-bitcoin/nixos-25.05";

    nixpkgs.follows = "nix-bitcoin/nixpkgs";
    nixpkgs-unstable.follows = "nix-bitcoin/nixpkgs-unstable";
    extra-container.follows = "nix-bitcoin/extra-container";
  };

  outputs = { nixpkgs, nix-bitcoin, extra-container, ... }:
    extra-container.lib.eachSupportedSystem (system: {
      packages.default = extra-container.lib.buildContainers {
        inherit system;

        # The container uses the nixpkgs from `nix-bitcoin.inputs.nixpkgs` by default

        # Only set this if the `system.stateVersion` of your container
        # host is < 22.05
        # legacyInstallDirs = true;

        config = {
          containers.mynode = {
            # Always start container along with the container host
            autoStart = true;

            # This assigns the following addresses:
            # Host IP:      10.250.0.1
            # Container IP: 10.250.0.2
            extra.addressPrefix = "10.250.0";

            # Enable internet access for the container
            extra.enableWAN = true;

            # Map `/my/host/dir` to `/my/mount` in the container
            # bindMounts."/my/mount" = { hostPath = "/my/host/dir"; isReadOnly = false; };

            # Setup port forwarding
            # forwardPorts = [ { containerPort = 80; hostPort = 8080; protocol = "tcp";} ];

            config = { config, pkgs, ... }: {
              imports = [
                nix-bitcoin.nixosModules.default
              ];

              # Automatically generate all secrets required by services.
              # The secrets are stored in /etc/nix-bitcoin-secrets in the container
              nix-bitcoin.generateSecrets = true;

              # Enable some services.
              # See ../configuration.nix for all available features.
              services.bitcoind.enable = true;
              services.electrs.enable = true;
            };
          };
        };
      };
    });
}
