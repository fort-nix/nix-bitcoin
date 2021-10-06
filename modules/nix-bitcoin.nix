{ config, pkgs, lib, ... }:

with lib;
{
  options = {
    nix-bitcoin = {
      pkgs = mkOption {
        type = types.attrs;
        default = (import ../pkgs { inherit pkgs; }).modulesPkgs;
      };

      lib = mkOption {
        readOnly = true;
        default = import ../pkgs/lib.nix lib pkgs;
      };

      torClientAddressWithPort = mkOption {
        readOnly = true;
        default = with config.services.tor.client.socksListenAddress;
          "${addr}:${toString port}";
      };

      # Torify binary that works with custom Tor SOCKS addresses
      # Related issue: https://github.com/NixOS/nixpkgs/issues/94236
      torify = mkOption {
        readOnly = true;
        default = pkgs.writeScriptBin "torify" ''
          ${pkgs.tor}/bin/torify \
            --address ${config.services.tor.client.socksListenAddress.addr} \
            "$@"
        '';
      };

      # A helper for using doas instead of sudo when doas is enabled
      runAsUserCmd = mkOption {
        readOnly = true;
        default = if config.security.doas.enable
                  # TODO: Use absolute path until https://github.com/NixOS/nixpkgs/pull/133622 is available.
                  then "/run/wrappers/bin/doas -u"
                  else "sudo -u";
      };
    };
  };
}
