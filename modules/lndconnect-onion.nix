{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    services.lnd.lndconnectOnion.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Create an onion service for the lnd REST server.
        Add a `lndconnect-onion` binary to the system environment.
        See: https://github.com/LN-Zap/lndconnect

        Usage:
        ```
          # Print QR code
          lndconnect-onion

          # Print URL
          lndconnect-onion --url
        ```
      '';
    };

    services.clightning-rest.lndconnectOnion.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Create an onion service for clightning-rest.
        Add a `lndconnect-onion-clightning` binary to the system environment.
        See: https://github.com/LN-Zap/lndconnect

        Usage:
        ```
          # Print QR code
          lndconnect-onion-clightning

          # Print URL
          lndconnect-onion-clightning --url
        ```
      '';
    };
  };

  nbLib = config.nix-bitcoin.lib;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  inherit (config.services)
    lnd
    clightning
    clightning-rest;

  mkLndconnect = {
    name,
    shebang ? "#!${pkgs.stdenv.shell} -e",
    onionService,
    port,
    certPath,
    macaroonPath
  }:
  # TODO-EXTERNAL:
  # lndconnect requires a --configfile argument, although it's unused
  # https://github.com/LN-Zap/lndconnect/issues/25
  pkgs.writeScriptBin name ''
    ${shebang}
    exec ${config.nix-bitcoin.pkgs.lndconnect}/bin/lndconnect \
     --host=$(cat ${config.nix-bitcoin.onionAddresses.dataDir}/${onionService}) \
     --port=${toString port} \
     --tlscertpath='${certPath}' \
     --adminmacaroonpath='${macaroonPath}' \
     --configfile=/dev/null "$@"
  '';

  operatorName = config.nix-bitcoin.operator.name;
in {
  inherit options;

  config = mkMerge [
    (mkIf (lnd.enable && lnd.lndconnectOnion.enable) {
      services.tor = {
        enable = true;
        relay.onionServices.lnd-rest = nbLib.mkOnionService {
          target.addr = nbLib.address lnd.restAddress;
          target.port = lnd.restPort;
          port = lnd.restPort;
        };
      };
      nix-bitcoin.onionAddresses.access.${lnd.user} = [ "lnd-rest" ];

      environment.systemPackages = [(
        mkLndconnect {
          name = "lndconnect-onion";
          # Run as lnd user because the macaroon and cert are not group-readable
          shebang = "#!/usr/bin/env -S ${runAsUser} ${lnd.user} ${pkgs.bash}/bin/bash";
          onionService = "${lnd.user}/lnd-rest";
          port = lnd.restPort;
          certPath = lnd.certPath;
          macaroonPath = "${lnd.networkDir}/admin.macaroon";
        }
      )];
    })

    (mkIf (clightning-rest.enable && clightning-rest.lndconnectOnion.enable) {
      services.tor = {
        enable = true;
        relay.onionServices.clightning-rest = nbLib.mkOnionService {
          target.addr = nbLib.address clightning-rest.address;
          target.port = clightning-rest.port;
          port = clightning-rest.port;
        };
      };
      # This also allows nodeinfo to show the clightning-rest onion address
      nix-bitcoin.onionAddresses.access.${operatorName} = [ "clightning-rest" ];

      environment.systemPackages = [(
        mkLndconnect {
          name = "lndconnect-onion-clightning";
          onionService = "${operatorName}/clightning-rest";
          port = clightning-rest.port;
          certPath = "${clightning-rest.dataDir}/certs/certificate.pem";
          macaroonPath = "${clightning-rest.dataDir}/certs/access.macaroon";
        }
      )];
    })
  ];
}
