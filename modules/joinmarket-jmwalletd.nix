{ config, lib, pkgs, ... }:

with lib;
let
  options.services.joinmarket-jmwalletd = {
    enable = mkEnableOption "JoinMarket jmwalletd";

    # Unfortunately it's not possible to set the listening address for
    # jmwalletd. It's used only internally.
    address = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      default = "127.0.0.1";
      description = mdDoc ''
        The address where the jmwalletd listens to.
      '';
    };
    port = mkOption {
      type = types.port;
      default = 28183;
      description = mdDoc "The port over which to serve RPC.";
    };
    wssPort = mkOption {
      type = types.port;
      default = 28283;
      description = mdDoc "The port over which to serve websocket subscriptions.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = mdDoc "Extra coomand line arguments passed to jmwalletd.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket-jmwalletd";
      description = mdDoc "The user as which to run JoinMarket jmwalletd.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = mdDoc "The group as which to run JoinMarket jmwalletd.";
    };
    dataDir = mkOption {
      readOnly = true;
      type = types.path;
      default = config.services.joinmarket.dataDir;
      description = mdDoc "The JoinMarket data directory.";
    };
    sslDir = mkOption {
      readOnly = true;
      type = types.path;
      default = "${cfg.dataDir}/ssl";
      description = mdDoc "The SSL directory for jmwalled.";
    };
    certPath = mkOption {
      readOnly = true;
      default = "${secretsDir}/joinmarket-jmwalletd";
      description = mdDoc "JoinMarket jmwalletd TLS certificate path.";
    };
    recoverSync = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Choose to do detailed wallet sync, used for recovering on new Core
        instance.
      '';
    };
    certificate = {
      extraIPs = mkOption {
        type = with types; listOf str;
        default = [];
        example = [ "60.100.0.1" ];
        description = mdDoc ''
          Extra `subjectAltName` IPs added to the certificate.
        '';
      };
      extraDomains = mkOption {
        type = with types; listOf str;
        default = [];
        example = [ "example.com" ];
        description = mdDoc ''
          Extra `subjectAltName` domain names added to the certificate.
        '';
      };
    };
  };

  cfg = config.services.joinmarket-jmwalletd;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;
in {
  inherit options;

  config = mkIf cfg.enable (mkMerge [{
    services.joinmarket.enable = true;

    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        # Allow access to the joinmarket dataDir.
        extraGroups = [ config.services.joinmarket.group ];
      };
      groups.${cfg.group} = {};
    };

    nix-bitcoin = {
      secrets.joinmarket-jmwalletd-password.user = cfg.user;
      generateSecretsCmds.joinmarket-jmwalletd-password = ''
        makePasswordSecret joinmarket-jmwalletd-password
      '';
    };
  }

  (mkIf cfg.enable {
    nix-bitcoin = {
      secrets = {
        joinmarket-jmwalletd-cert.user = cfg.user;
        joinmarket-jmwalletd-key.user = cfg.user;
      };
      generateSecretsCmds.joinmarket-jmwalletd = ''
        makeCert joinmarket-jmwalletd '${nbLib.mkCertExtraAltNames cfg.certificate}'
      '';
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.sslDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.joinmarket-jmwalletd = {
      wantedBy = [ "joinmarket.service" ];
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" "nix-bitcoin-secrets.target" ];
      preStart = ''
        # Copy the certificates into a data directory under the `ssl` dir
        mkdir -p '${cfg.sslDir}'
        install -m600 '${cfg.certPath}-cert' '${cfg.sslDir}/cert.pem'
        install -m600 '${cfg.certPath}-key' '${cfg.sslDir}/key.pem'
      '';
      serviceConfig = nbLib.defaultHardening // {
        WorkingDirectory = cfg.dataDir;
        User = cfg.user;
        ExecStart = ''
          ${config.nix-bitcoin.pkgs.joinmarket}/bin/jm-jmwalletd \
          --port='${toString cfg.port}' \
          --wss-port='${toString cfg.wssPort}' \
          --datadir='${cfg.dataDir}' \
          ${optionalString (cfg.recoverSync) "--recoversync \\"}
          ${cfg.extraArgs}
        '';
        SyslogIdentifier = "joinmarket-jmwalletd";
        ReadWritePaths = [ cfg.dataDir ];
        Restart = "on-failure";
        RestartSec = "10s";
        MemoryDenyWriteExecute = false;
      } // nbLib.allowTor;
    };
  })
  ]);
}
