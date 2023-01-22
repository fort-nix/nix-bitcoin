{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    services.lnd.lndconnect = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Add a `lndconnect` binary to the system environment which prints
          connection info for lnd clients.
          See: https://github.com/LN-Zap/lndconnect

          Usage:
          ```bash
            # Print QR code
            lndconnect

            # Print URL
            lndconnect --url
          ```
        '';
      };
      onion = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Create an onion service for the lnd REST server,
          which is used by lndconnect.
        '';
      };
    };


    services.clightning-rest.lndconnect = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
        Add a `lndconnect-clightning` binary to the system environment which prints
        connection info for clightning clients.
        See: https://github.com/LN-Zap/lndconnect

        Usage:
        ```bash
          # Print QR code
          lndconnect-clightning

          # Print URL
          lndconnect-clightning --url
        ```
      '';
      };
      onion = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Create an onion service for the clightning REST server,
          which is used by lndconnect.
        '';
      };
    };

    nix-bitcoin.mkLndconnect = mkOption {
      readOnly = true;
      default = mkLndconnect;
      description = mdDoc ''
        A function to create a lndconnect binary.
        See the source for further details.
      '';
    };
  };

  nbLib = config.nix-bitcoin.lib;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  inherit (config.services)
    lnd
    clightning-rest;

  mkLndconnect = {
    name,
    shebang ? "#!${pkgs.stdenv.shell} -e",
    port,
    macaroonPath,
    enableOnion,
    onionService ? null,
    certPath ? null
  }:
  # TODO-EXTERNAL:
  # lndconnect requires a --configfile argument, although it's unused
  # https://github.com/LN-Zap/lndconnect/issues/25
  pkgs.hiPrio (pkgs.writeScriptBin name ''
    ${shebang}
    exec ${config.nix-bitcoin.pkgs.lndconnect}/bin/lndconnect \
     ${optionalString enableOnion "--host=$(cat ${config.nix-bitcoin.onionAddresses.dataDir}/${onionService})"} \
     --port=${toString port} \
     ${if enableOnion || certPath == null then "--nocert" else "--tlscertpath='${certPath}'"} \
     --adminmacaroonpath='${macaroonPath}' \
     --configfile=/dev/null "$@"
  '');

  operatorName = config.nix-bitcoin.operator.name;
in {
  inherit options;

  config = mkMerge [
    (mkIf (lnd.enable && lnd.lndconnect.enable)
      (mkMerge [
        {
          environment.systemPackages = [(
            mkLndconnect {
              name = "lndconnect";
              # Run as lnd user because the macaroon and cert are not group-readable
              shebang = "#!/usr/bin/env -S ${runAsUser} ${lnd.user} ${pkgs.bash}/bin/bash";
              enableOnion = lnd.lndconnect.onion;
              onionService = "${lnd.user}/lnd-rest";
              port = lnd.restPort;
              certPath = lnd.certPath;
              macaroonPath = "${lnd.networkDir}/admin.macaroon";
            }
          )];

          services.lnd.restAddress = mkIf (!lnd.lndconnect.onion) "0.0.0.0";
        }

        (mkIf lnd.lndconnect.onion {
          services.tor = {
            enable = true;
            relay.onionServices.lnd-rest = nbLib.mkOnionService {
              target.addr = nbLib.address lnd.restAddress;
              target.port = lnd.restPort;
              port = lnd.restPort;
            };
          };
          nix-bitcoin.onionAddresses.access.${lnd.user} = [ "lnd-rest" ];
        })
      ]))

    (mkIf (clightning-rest.enable && clightning-rest.lndconnect.enable)
      (mkMerge [
        {
          environment.systemPackages = [(
            mkLndconnect {
              name = "lndconnect-clightning";
              enableOnion = clightning-rest.lndconnect.onion;
              onionService = "${operatorName}/clightning-rest";
              port = clightning-rest.port;
              certPath = "${clightning-rest.dataDir}/certs/certificate.pem";
              macaroonPath = "${clightning-rest.dataDir}/certs/access.macaroon";
            }
          )];

          # clightning-rest always binds to all interfaces
        }

        (mkIf clightning-rest.lndconnect.onion {
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
        })
      ])
    )
  ];
}
