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
    ./lightning-charge.nix
    ./nanopos.nix
    ./spark-wallet.nix
    ./lnd.nix
    ./lightning-loop.nix
    ./btcpayserver.nix
    ./electrs.nix
    ./liquid.nix
    ./joinmarket.nix
    ./hardware-wallets.nix
    ./recurring-donations.nix

    # Support features
    ./versioning.nix
    ./security.nix
    ./netns-isolation.nix
    ./backups.nix
    ./onion-chef.nix
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];

  options = {
    nix-bitcoin-services = mkOption {
      readOnly = true;
      default = import ./nix-bitcoin-services.nix lib pkgs;
    };

    nix-bitcoin = {
      pkgs = mkOption {
        type = types.attrs;
        default = (import ../pkgs { inherit pkgs; }).modulesPkgs;
      };

      # Torify binary that works with custom Tor SOCKS addresses
      # Related issue: https://github.com/NixOS/nixpkgs/issues/94236
      torify = mkOption {
        readOnly = true;
        default = pkgs.writeScriptBin "torify" ''
          ${pkgs.tor}/bin/torify \
            --address ${head (splitString ":" config.services.tor.client.socksListenAddress)} \
            "$@"
        '';
      };
    };
  };

  config = {
    assertions = [
      { assertion = (config.services.lnd.enable -> ( !config.services.clightning.enable || config.services.clightning.bindport != config.services.lnd.listenPort));
        message = ''
          LND and clightning can't both bind to lightning port 9735. Either
          disable LND/clightning or change services.clightning.bindPort or
          services.lnd.listenPort to a port other than 9735.
        '';
      }
    ];
  };
}
