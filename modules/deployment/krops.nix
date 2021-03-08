{ lib, ... }:
{
  nix-bitcoin = {
    secretsDir = "/var/src/secrets";
    setup-secrets = true;
  };
  environment.variables.NIX_PATH = lib.mkForce "/var/src";
}
