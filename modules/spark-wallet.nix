{ config, lib, pkgs, ... }:

with lib;
let
  options.services.spark-wallet = {
    enable = mkEnableOption "spark-wallet";
    address = mkOption {
      type = types.str;
      default = "localhost";
      description = mdDoc "http(s) server address.";
    };
    port = mkOption {
      type = types.port;
      default = 9737;
      description = mdDoc "http(s) server port.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = mdDoc "Extra command line arguments passed to spark-wallet.";
    };
    getPublicAddressCmd = mkOption {
      type = types.str;
      default = "";
      description = mdDoc ''
        Bash expression which outputs the public service address.
        If set, spark-wallet prints a QR code to the systemd journal which
        encodes an URL for accessing the web interface.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "spark-wallet";
      description = mdDoc "The user as which to run spark-wallet.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = mdDoc "The group as which to run spark-wallet.";
    };
    tor = nbLib.tor;
  };

  cfg = config.services.spark-wallet;
  nbLib = config.nix-bitcoin.lib;

  clightning = config.services.clightning;

  # Use wasabi rate provider because the default (bitstamp) doesn't accept
  # connections through Tor
  torRateProvider = "--rate-provider wasabi --proxy socks5h://${config.nix-bitcoin.torClientAddressWithPort}";
  startScript = ''
    ${optionalString (cfg.getPublicAddressCmd != "") ''
      publicURL=(--public-url "http://$(${cfg.getPublicAddressCmd})")
    ''}
    exec ${config.nix-bitcoin.pkgs.spark-wallet}/bin/spark-wallet \
      --ln-path '${clightning.networkDir}'  \
      --host ${cfg.address} --port ${toString cfg.port} \
      --config '${config.nix-bitcoin.secretsDir}/spark-wallet-login' \
      ${optionalString cfg.tor.proxy torRateProvider} \
      ${optionalString (cfg.getPublicAddressCmd != "") ''"''${publicURL[@]}"''} \
      --pairing-qr --print-key ${cfg.extraArgs}
  '';
in {
  inherit options;

  config = mkIf cfg.enable {
    services.clightning.enable = true;

    systemd.services.spark-wallet = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      script = startScript;
      serviceConfig = nbLib.defaultHardening // {
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // nbLib.nodejs;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ clightning.group ];
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets.spark-wallet-login.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.spark-wallet = ''
      makePasswordSecret spark-wallet-password
      if [[ spark-wallet-password -nt spark-wallet-login ]]; then
         echo "login=spark-wallet:$(cat spark-wallet-password)" > spark-wallet-login
      fi
    '';
  };
}
