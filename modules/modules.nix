{ config, pkgs, lib, ... }:

{
  imports = [
    # Core modules
    ./secrets/secrets.nix
    ./operator.nix

    # Main features
    ./bitcoind.nix
    ./clightning.nix
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
    nix-bitcoin-services = lib.mkOption {
      readOnly = true;
      default = import ./nix-bitcoin-services.nix lib pkgs;
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

    nixpkgs.overlays = [ (self: super: {
      nix-bitcoin = let
        pkgs = import ../pkgs { pkgs = super; };
      in
        pkgs // pkgs.pinned;
    }) ];
  };
}
