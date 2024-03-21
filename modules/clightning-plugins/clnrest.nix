{ config, lib, ... }:

with lib;
let
  options.services.clightning.plugins.clnrest = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable clnrest (clightning plugin).

        clnrest provides a clightning REST API, using clightning RPC calls as its backend.
        It also broadcasts clightning notifications to listeners connected to its websocket server.

        See here for all available options:
        https://docs.corelightning.org/docs/rest
        Extra options can be set via `services.clightning.extraConfig`.
      '';
    };
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = mdDoc "Address to listen for REST connections.";
    };
    port = mkOption {
      type = types.port;
      default = 3010;
      description = mdDoc "REST server port.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.nbPython3Packages.clnrest;
      defaultText = "config.nix-bitcoin.pkgs.nbPython3Packages.clnrest";
      description = mdDoc "The package providing clnrest binaries.";
    };
  };

  cfg = config.services.clightning.plugins.clnrest;
  inherit (config.services) clightning;
in
{
  inherit options;

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/clnrest
      clnrest-host=${cfg.address}
      clnrest-port=${toString cfg.port}
    '';
  };
}
