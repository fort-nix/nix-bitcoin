# This module creates onion-services for NixOS services.
# An onion service can be enabled for every service that defines
# options 'address', 'port' and optionally 'getPublicAddressCmd'.
#
# See it in use at ./presets/enable-tor.nix

{ config, lib, pkgs, ... }:

with lib;
let
  options.nix-bitcoin.onionServices = mkOption {
    default = {};
    type = with types; attrsOf (submodule (
      { config, ... }: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = config.public;
            description = mdDoc ''
              Create an onion service for the given service.
              The service must define options {option}'address' and {option}'onionPort' (or `port`).
            '';
          };
          public = mkOption {
            type = types.bool;
            default = false;
            description = mdDoc ''
              Make the onion address accessible to the service.
              If enabled, the onion service is automatically enabled.
              Only available for services that define option {option}`getPublicAddressCmd`.
            '';
          };
          externalPort = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = mdDoc "Override the external port of the onion service.";
          };
        };
      }
    ));
  };

  cfg = config.nix-bitcoin.onionServices;
  nbLib = config.nix-bitcoin.lib;

  onionServices = builtins.attrNames cfg;

  activeServices = builtins.filter (service:
    config.services.${service}.enable && cfg.${service}.enable
  ) onionServices;

  publicServices = builtins.filter (service: cfg.${service}.public) activeServices;
in {
  inherit options;

  config = mkMerge [
    (mkIf (activeServices != []) {
      # Define hidden services
      services.tor = {
        enable = true;
        relay.onionServices = genAttrs activeServices (name:
          let
            service = config.services.${name};
            inherit (cfg.${name}) externalPort;
          in nbLib.mkOnionService {
            port = if externalPort != null then externalPort else service.port;
            target.port = service.onionPort or service.port;
            target.addr = nbLib.address service.address;
          }
        );
      };

      nix-bitcoin.onionAddresses = {
        # Enable public services to access their own onion addresses
        services = publicServices;

        # Allow the operator user to access onion addresses for all active services
        access.${config.nix-bitcoin.operator.name} = mkIf config.nix-bitcoin.operator.enable activeServices;
      };
      systemd.services = let
        onionAddresses = [ "onion-addresses.service" ];
      in genAttrs publicServices (service: {
        # TODO-EXTERNAL: Instead of `wants`, use a future systemd dependency type
        # that propagates initial start failures but no restarts
        wants = onionAddresses;
        after = onionAddresses;
      });
    })

    # Set getPublicAddressCmd for public services
    {
      services = let
        # publicServices' doesn't depend on config.services.*.enable,
        # so we can use it to define config.services without causing infinite recursion
        publicServices' = builtins.filter (service:
          let srv = cfg.${service};
          in srv.public && srv.enable
        ) onionServices;
      in genAttrs publicServices' (service: {
        getPublicAddressCmd = "cat ${config.nix-bitcoin.onionAddresses.dataDir}/services/${service}";
      });
    }

    # Set sensible defaults for some services
    {
      nix-bitcoin.onionServices = {
        spark-wallet = {
          externalPort = 80;
          # Enable 'public' by default, but don't auto-enable the onion service.
          # When the onion service is enabled, 'public' lets spark-wallet generate
          # a QR code for accessing the web interface.
          public = true;
          # Low priority so we can override this with mkDefault in ./presets/enable-tor.nix
          enable = mkOverride 1400 false;
        };
        btcpayserver = {
          externalPort = 80;
        };
        joinmarket-ob-watcher = {
          externalPort = 80;
        };
        rtl = {
          externalPort = 80;
        };
        torq = {
          externalPort = 80;
        };
      };
    }
  ];
}
