{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    services.lnd.lndconnect = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
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
        description = ''
          Create an onion service for the lnd REST server,
          which is used by lndconnect.
        '';
      };
    };

    services.clightning.plugins.clnrest.lnconnect = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Add a `lnconnect-clnrest` binary to the system environment which prints
          connection info for clightning clients.
          See: https://github.com/LN-Zap/lndconnect

          Usage:
          ```bash
            # Print QR code
            lnconnect-clnrest

            # Print URL
            lnconnect-clnrest --url
          ```
        '';
      };
      onion = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Create an onion service for the clnrest server,
          which is used by lnconnect.
        '';
      };
    };

    services.clightning-rest.lndconnect = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
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
        description = ''
          Create an onion service for the clightning REST server,
          which is used by lndconnect.
        '';
      };
    };

    nix-bitcoin.mkLndconnect = mkOption {
      readOnly = true;
      default = mkLndconnect;
      description = ''
        A function to create a lndconnect binary.
        See the source for further details.
      '';
    };
  };

  nbLib = config.nix-bitcoin.lib;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  inherit (config.services)
    lnd
    clightning
    clightning-rest;

  inherit (clightning.plugins) clnrest;

  mkLndconnect = {
    name,
    shebang ? "#!${pkgs.stdenv.shell} -e",
    isClightning ? false,
    isClnrest ? false,
    port,
    authSecretPath,
    enableOnion,
    onionService ? null,
    certPath ? null
  }:
  # TODO-EXTERNAL:
  # lndconnect requires a --configfile argument, although it's unused
  # https://github.com/LN-Zap/lndconnect/issues/25
  lib.hiPrio (pkgs.writeScriptBin name ''
    ${shebang}
    url=$(
      ${getExe config.nix-bitcoin.pkgs.lndconnect} --url \
        ${optionalString enableOnion "--host=$(cat ${config.nix-bitcoin.onionAddresses.dataDir}/${onionService})"} \
        --port=${toString port} \
        ${if enableOnion || certPath == null then "--nocert" else "--tlscertpath='${certPath}'"} \
        --adminmacaroonpath='${authSecretPath}' \
        --configfile=/dev/null "$@"
    )

    ${optionalString isClightning
      # - Change URL procotcol to c-lightning-rest
      # - Encode macaroon as hex (in uppercase) instead of base 64.
      #   Because `macaroon` is always the last URL fragment, the
      #   sed replacement below works correctly.
      ''
        macaroonHex=$(${getExe pkgs.xxd} -p -u -c 99999 '${authSecretPath}')
        url=$(
          echo "$url" | ${getExe pkgs.gnused} "
            s|^lndconnect|c-lightning-rest|
            s|macaroon=.*|macaroon=$macaroonHex|
          ";
        )
      ''
    }

    ${optionalString isClnrest
      # Change URL procotcol to clnrest
      ''
        url=$(
          echo "$url" | ${getExe pkgs.gnused} "
            s|^lndconnect|clnrest|
            s|macaroon=.*|rune=$(cat '${authSecretPath}')|
          ";
        )
      ''
     }

    # If --url is in args
    if [[ " $* " =~ " --url " ]]; then
      echo "$url"
    else
      # This UTF-8 encoding yields a smaller, more convenient output format
      # compared to the native lndconnect output
      echo -n "$url" | ${getExe pkgs.qrencode} -t UTF8 -o -
    fi
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
              authSecretPath = "${lnd.networkDir}/admin.macaroon";
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
          nix-bitcoin.onionAddresses.access = {
            ${lnd.user} = [ "lnd-rest" ];
            ${operatorName} = [ "lnd-rest" ];
          };
        })
      ]))

    (mkIf (clnrest.enable && clnrest.lnconnect.enable)
      (mkMerge [
        {
          environment.systemPackages = [(
            mkLndconnect {
              name = "lnconnect-clnrest";
              isClnrest = true;
              enableOnion = clnrest.lnconnect.onion;
              onionService = "${operatorName}/clnrest";
              port = clnrest.port;
              certPath = "${clightning.networkDir}/client.pem";
              authSecretPath = "${clightning.networkDir}/admin-rune";
            }
          )];

          services.clightning.plugins.clnrest.address = mkIf (!clnrest.lnconnect.onion) "0.0.0.0";
        }

        (mkIf clnrest.lnconnect.onion {
          services.tor = {
            enable = true;
            relay.onionServices.clnrest = nbLib.mkOnionService {
              target.addr = nbLib.address clnrest.address;
              target.port = clnrest.port;
              port = clnrest.port;
            };
          };
          # This also allows nodeinfo to show the clnrest onion address
          nix-bitcoin.onionAddresses.access.${operatorName} = [ "clnrest" ];
        })
      ])
    )

    (mkIf (clightning-rest.enable && clightning-rest.lndconnect.enable)
      (mkMerge [
        {
          environment.systemPackages = [(
            mkLndconnect {
              name = "lndconnect-clightning";
              isClightning = true;
              enableOnion = clightning-rest.lndconnect.onion;
              onionService = "${operatorName}/clightning-rest";
              port = clightning-rest.port;
              certPath = "${clightning-rest.dataDir}/certs/certificate.pem";
              authSecretPath = "${clightning-rest.dataDir}/certs/access.macaroon";
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
