{ lib, ... }:
{
  nix-bitcoin = {
    secretsDir = "/var/src/secrets";
    setupSecrets = true;
  };
  environment.variables.NIX_PATH = lib.mkForce "/var/src";
}
