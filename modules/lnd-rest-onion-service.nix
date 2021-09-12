{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lnd.restOnionService;
  nbLib = config.nix-bitcoin.lib;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  lnd = config.services.lnd;

  bin = pkgs.writeScriptBin "lndconnect-rest-onion" ''
    #!/usr/bin/env -S ${runAsUser} ${lnd.user} ${pkgs.bash}/bin/bash

    exec ${cfg.package}/bin/lndconnect \
     --host=$(cat ${config.nix-bitcoin.onionAddresses.dataDir}/lnd/lnd-rest) \
     --port=${toString lnd.restPort} \
     --lnddir=${lnd.dataDir} \
     --tlscertpath=${lnd.certPath} "$@"
  '';
in {
  options.services.lnd.restOnionService = {
    enable = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Create an onion service for the lnd REST service.
        Add a `lndconnect-rest-onion` binary (https://github.com/LN-Zap/lndconnect) to the system environment.
        This binary generates QR codes or URIs for connecting applications to lnd via the REST onion service.
      '';
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.lndconnect;
      description = "The package providing lndconnect binaries.";
    };
  };

  config = mkIf cfg.enable {
    services.tor = {
      enable = true;
      relay.onionServices.lnd-rest = nbLib.mkOnionService {
        target.addr = lnd.restAddress;
        target.port = lnd.restPort;
        port = lnd.restPort;
      };
    };
    nix-bitcoin.onionAddresses.access.lnd = [ "lnd-rest" ];

    environment.systemPackages = [ bin ];
  };
}
