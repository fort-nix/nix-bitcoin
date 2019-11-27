{ config, pkgs, lib, ... }:

# This is mainly for testing.
# When using this for regular deployments, make sure to create a backup of the
# generated secrets.

with lib;
let
  secretsDir = "/secrets/"; # TODO: make this an option
in
{
  nix-bitcoin.setup-secrets = true;

  systemd.services.generate-secrets = {
    requiredBy = [ "setup-secrets.service" ];
    before = [ "setup-secrets.service" ];
    serviceConfig = {
       Type = "oneshot";
       RemainAfterExit = true;
    } // config.nix-bitcoin-services.defaultHardening;
    script = ''
      mkdir -p "${secretsDir}"
      cd "${secretsDir}"
      chown root: .
      chmod 0700 .
      ${pkgs.nix-bitcoin.generate-secrets}
    '';
  };
}
