{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.spark-wallet;
  inherit (config) nix-bitcoin-services;

  # Use wasabi rate provider because the default (bitstamp) doesn't accept
  # connections through Tor
  torRateProvider = "--rate-provider wasabi --proxy socks5h://${config.services.tor.client.socksListenAddress}";
  startScript = ''
    ${optionalString (cfg.getPublicAddressCmd != "") ''
      publicURL="--public-url http://$(${cfg.getPublicAddressCmd})"
    ''}
    exec ${config.nix-bitcoin.pkgs.spark-wallet}/bin/spark-wallet \
      --ln-path '${config.services.clightning.networkDir}'  \
      --host ${cfg.address} --port ${toString cfg.port} \
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
    address = mkOption {
      type = types.str;
      default = "localhost";
      description = "http(s) server address.";
    };
    port = mkOption {
      type = types.port;
      default = 9737;
      description = "http(s) server port.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to spark-wallet.";
    };
    getPublicAddressCmd = mkOption {
      type = types.str;
      default = "";
      description = ''
        Bash expression which outputs the public service address.
        If set, spark-wallet prints a QR code to the systemd journal which
        encodes an URL for accessing the web interface.
      '';
    };
    inherit (nix-bitcoin-services) enforceTor;
  };

  config = mkIf cfg.enable {
    services.clightning.enable = true;

    users.users.spark-wallet = {
      description = "spark-wallet User";
      group = "spark-wallet";
      extraGroups = [ "clightning" ];
    };
    users.groups.spark-wallet = {};

    systemd.services.spark-wallet = {
      description = "Run spark-wallet";
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      script = startScript;
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        User = "spark-wallet";
        Restart = "on-failure";
        RestartSec = "10s";
      } // (if cfg.enforceTor
            then nix-bitcoin-services.allowTor
            else nix-bitcoin-services.allowAnyIP)
        // nix-bitcoin-services.nodejs;
    };
    nix-bitcoin.secrets.spark-wallet-login.user = "spark-wallet";
  };
}
