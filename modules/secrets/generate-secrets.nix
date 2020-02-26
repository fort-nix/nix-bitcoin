{ config, pkgs, lib, ... }:

# This is mainly for testing.
# When using this for regular deployments, make sure to create a backup of the
# generated secrets.

with lib;
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
      mkdir -p "${config.nix-bitcoin.secretsDir}"
      cd "${config.nix-bitcoin.secretsDir}"
      chown root: .
      chmod 0700 .
      ${pkgs.nix-bitcoin.generate-secrets}
    '';
  };
}
