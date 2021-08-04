{ config, pkgs, lib, ... }:

with lib;
{
  imports = [
    # Core modules
    ./secrets/secrets.nix
    ./operator.nix

    # Main features
    ./bitcoind.nix
    ./clightning.nix
    ./clightning-plugins
    ./spark-wallet.nix
    ./lnd.nix
    ./lnd-rest-onion-service.nix
    ./lightning-loop.nix
    ./lightning-pool.nix
    ./charge-lnd.nix
    ./btcpayserver.nix
    ./electrs.nix
    ./liquid.nix
    ./joinmarket.nix
    ./joinmarket-ob-watcher.nix
    ./hardware-wallets.nix
    ./recurring-donations.nix

    # Support features
    ./versioning.nix
    ./security.nix
    ./onion-addresses.nix
    ./onion-services.nix
    ./netns-isolation.nix
    ./nodeinfo.nix
    ./backups.nix
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];

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
        default =  with config.services.tor.client.socksListenAddress;
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
                  then "doas -u"
                  else "sudo -u";
      };
    };
  };

  config = {
    assertions = [
      { assertion = (config.services.lnd.enable -> ( !config.services.clightning.enable || config.services.clightning.port != config.services.lnd.port));
        message = ''
          LND and clightning can't both bind to lightning port 9735. Either
          disable LND/clightning or change services.clightning.bindPort or
          services.lnd.port to a port other than 9735.
        '';
      }
    ];
  };
}
