# This module creates onion-services for NixOS services.
# An onion service can be enabled for every service that defines
# options 'address', 'port' and optionally 'getPublicAddressCmd'.
#
# See it in use at ./presets/enable-tor.nix

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-bitcoin.onionServices;

  services = builtins.attrNames cfg;

  activeServices = builtins.filter (service:
    config.services.${service}.enable && cfg.${service}.enable
  ) services;

  publicServices = builtins.filter (service: cfg.${service}.public) activeServices;
in {
  options.nix-bitcoin.onionServices = mkOption {
    default = {};
    type = with types; attrsOf (submodule (
      { config, ... }: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = config.public;
            description = ''
              Create an onion service for the given service.
              The service must define options 'address' and 'port'.
            '';
          };
          public = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Make the onion address accessible to the service.
              If enabled, the onion service is automatically enabled.
              Only available for services that define option `getPublicAddressCmd`.
            '';
          };
          externalPort = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Override the external port of the onion service.";
          };
        };
      }
    ));
  };

  config = mkMerge [
    (mkIf (cfg != {}) {
      # Define hidden services
      services.tor = {
        enable = true;
        hiddenServices = genAttrs activeServices (name:
          let
            service = config.services.${name};
            inherit (cfg.${name}) externalPort;
          in {
            map = [{
              port = if externalPort != null then externalPort else service.port;
              toPort = service.port;
              toHost = if service.address == "0.0.0.0" then "127.0.0.1" else service.address;
            }];
            version = 3;
          }
        );
      };

      # Enable public services to access their own onion addresses
      nix-bitcoin.onionAddresses.access = (
        genAttrs publicServices singleton
      ) // {
        # Allow the operator user to access onion addresses for all active services
        ${config.nix-bitcoin.operator.name} = mkIf config.nix-bitcoin.operator.enable activeServices;
      };
      systemd.services = let
        onionAddresses = [ "onion-addresses.service" ];
      in genAttrs publicServices (service: {
        requires = onionAddresses;
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
        ) services;
      in genAttrs publicServices' (service: {
        getPublicAddressCmd = "cat ${config.nix-bitcoin.onionAddresses.dataDir}/${service}/${service}";
      });
    }
  ];
}
