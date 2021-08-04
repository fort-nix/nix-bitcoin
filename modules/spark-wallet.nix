{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.spark-wallet;
  nbLib = config.nix-bitcoin.lib;

  # Use wasabi rate provider because the default (bitstamp) doesn't accept
  # connections through Tor
  torRateProvider = "--rate-provider wasabi --proxy socks5h://${config.nix-bitcoin.torClientAddressWithPort}";
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
    enable = mkEnableOption "spark-wallet";
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
    user = mkOption {
      type = types.str;
      default = "spark-wallet";
      description = "The user as which to run spark-wallet.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run spark-wallet.";
    };
    inherit (nbLib) enforceTor;
  };

  config = mkIf cfg.enable {
    services.clightning.enable = true;

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ config.services.clightning.group ];
    };
    users.groups.${cfg.group} = {};

    systemd.services.spark-wallet = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      script = startScript;
      serviceConfig = nbLib.defaultHardening // {
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.enforceTor
        // nbLib.nodejs;
    };
    nix-bitcoin.secrets.spark-wallet-login.user = cfg.user;
  };
}
