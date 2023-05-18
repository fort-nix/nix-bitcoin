let
  # FIXME:
  #target = "root@HOSTNAME_OR_IP_ADDRESS";
  target = "root@console_jay";

  extraSources = {
    "hardware-configuration.nix".file = toString ../hardware-configuration.nix;
  };

  krops = (import <nix-bitcoin> {}).krops;
in
krops.pkgs.krops.writeDeploy "deploy" {
  inherit target;

  source = import ./sources.nix { inherit extraSources krops; };

  # Avoid having to create a sentinel file.
  # Otherwise /var/src/.populate must be created on the target node to signal krops
  # that it is allowed to deploy.
  force = true;
}
