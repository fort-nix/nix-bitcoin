{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.spark-wallet;
  inherit (config) nix-bitcoin-services;
  onion-chef-service = (if cfg.onion-service then [ "onion-chef.service" ] else []);

  # Use wasabi rate provider because the default (bitstamp) doesn't accept
  # connections through Tor
  torRateProvider = "--rate-provider wasabi --proxy socks5h://${config.services.tor.client.socksListenAddress}";
  startScript = ''
    ${optionalString cfg.onion-service ''
      publicURL="--public-url http://$(cat /var/lib/onion-chef/spark-wallet/spark-wallet)"
    ''}
    exec ${pkgs.nix-bitcoin.spark-wallet}/bin/spark-wallet \
      --ln-path '${config.services.clightning.networkDir}'  \
      --host ${cfg.host} \
      --config '${config.nix-bitcoin.secretsDir}/spark-wallet-login' \
      ${optionalString cfg.enforceTor torRateProvider} \
      $publicURL \
      --pairing-qr --print-key ${cfg.extraArgs}
  '';
in {
  options.services.spark-wallet = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the spark-wallet service will be installed.
      '';
    };
    host = mkOption {
      type = types.str;
      default = "localhost";
      description = "http(s) server listen address.";
    };
    onion-service = mkOption {
      type = types.bool;
      default = false;
      description = ''
        "If enabled, configures spark-wallet to be reachable through an onion service.";
      '';
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to spark-wallet.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    services.clightning.enable = true;

    users.users.spark-wallet = {
      description = "spark-wallet User";
      group = "spark-wallet";
      extraGroups = [ "clightning" ];
    };
    users.groups.spark-wallet = {};

    services.tor.hiddenServices.spark-wallet = mkIf cfg.onion-service {
      map = [{
        port = 80; toPort = 9737; toHost = cfg.host;
      }];
      version = 3;
    };
    services.onion-chef.enable = cfg.onion-service;
    services.onion-chef.access.spark-wallet = if cfg.onion-service then [ "spark-wallet" ] else [];
    systemd.services.spark-wallet = {
      description = "Run spark-wallet";
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ] ++ onion-chef-service;
      after = [ "clightning.service" ]  ++ onion-chef-service;
      script = startScript;
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        User = "spark-wallet";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = mkIf cfg.onion-service "/var/lib/onion-chef";
      } // (if cfg.enforceTor
            then nix-bitcoin-services.allowTor
            else nix-bitcoin-services.allowAnyIP)
        // nix-bitcoin-services.nodejs;
    };
    nix-bitcoin.secrets.spark-wallet-login.user = "spark-wallet";
  };
}
