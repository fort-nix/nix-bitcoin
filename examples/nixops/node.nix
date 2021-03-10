# This is an example network definition for deploying a nix-bitcoin node via NixOps.
# NixOps deployment is currently untested.

{
  network.description = "Bitcoin node";

  bitcoin-node = { config, pkgs, lib, ... }: {
    imports = [
      ../configuration.nix
      <nix-bitcoin/modules/deployment/nixops.nix>
    ];

    nix-bitcoin.deployment.secretsDir = toString ../secrets;

    #FIXME:
    # Set `deployment.*` options like
    # deployment.targetHost = "<address_or_hostname>";
  };
}
