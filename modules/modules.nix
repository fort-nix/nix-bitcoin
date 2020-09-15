{ config, pkgs, lib, ... }:

{
  imports = [
    ./bitcoind.nix
    ./clightning.nix
    ./lightning-charge.nix
    ./nanopos.nix
    ./liquid.nix
    ./spark-wallet.nix
    ./electrs.nix
    ./onion-chef.nix
    ./recurring-donations.nix
    ./hardware-wallets.nix
    ./lnd.nix
    ./lightning-loop.nix
    ./secrets/secrets.nix
    ./netns-isolation.nix
    ./security.nix
    ./backups.nix
    ./btcpayserver.nix
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
