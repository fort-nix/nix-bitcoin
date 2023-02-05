{ config, lib, pkgs, ... }:

with lib;
let
  options.services = {
    torq = {
      enable = mkEnableOption "torq, a capital management tool for lnd";
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = mdDoc "Address to listen on.";
      };
      port = mkOption {
        type = types.port;
        default = 8089;
        description = mdDoc "Port to listen on.";
      };
      settings = mkOption {
        type = settingsFormat.type;
        default = {};
        example = { torq.debug = true; };
        description = ''torq settings. See `torq --help` for possible options.'';
      };
      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.torq;
        defaultText = "config.nix-bitcoin.pkgs.torq";
        description = "The package providing torq binaries.";
      };
      user = mkOption {
        type = types.str;
        default = "torq";
        description = "The user as which to run torq.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run torq.";
      };
      tor.enforce = nbLib.tor.enforce;
    };
  };

  macaroonPermissions = {
    invoices = ["read" "write"];
    onchain = ["read" /*"write"*/];
    offchain = ["read" /*"write"*/];
    address = ["read" "write"];
    message = ["read" "write"];
    peers = ["read" "write"];
    info = ["read"];
    uri = ["/lnrpc.Lightning/UpdateChannelPolicy"];
  };
  macaroonPermissionsStr = concatStringsSep "," (
    mapAttrsToList (entity: actions: (
      concatStringsSep "," (map (action: ''{"entity":"${entity}","action":"${action}"}'') actions)
    )) macaroonPermissions
  );

  cfg = config.services.torq;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  settingsFormat = pkgs.formats.toml {};
  configFile = settingsFormat.generate "torq.toml" cfg.settings;

  dbName = "torq";
  dataDir = "/var/lib/torq";
in {
  inherit options;

  config = mkIf cfg.enable {
    services.lnd = {
      enable = true;
      macaroons.torq = {
        inherit (cfg) user;
        permissions = macaroonPermissionsStr;
      };
    };

    services.postgresql = let
      postgresqlPackages = config.services.postgresql.package.pkgs;
    in {
      enable = true;
      ensureDatabases = [ dbName ];
      ensureUsers = [
        {
          name = cfg.user;
          ensurePermissions."DATABASE \"${dbName}\"" = "ALL PRIVILEGES";
        }
      ];
      extraPlugins = with postgresqlPackages; [ timescaledb ];
      settings.shared_preload_libraries = "timescaledb";
    };

    services.torq.settings = {
      torq.port = toString cfg.port;
      torq.password = "";
      lnd.macaroon-path = "/run/lnd/torq.macaroon";
      lnd.tls-path = "/etc/nix-bitcoin-secrets/lnd-cert";
      lnd.url = "localhost:10009";
      db.name = "torq";
      db.host = "/run/postgresql";
      db.user = "torq";
    };

    systemd.services.torq-setup-db = rec {
      requires = [ "postgresql.service" ];
      after = requires;
      serviceConfig = nbLib.defaultHardening // {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        RemainAfterExit = true;
      };
      script = ''
        ${config.services.postgresql.package}/bin/psql ${dbName} -c "ALTER EXTENSION timescaledb UPDATE" || true
        ${config.services.postgresql.package}/bin/psql ${dbName} -c "CREATE EXTENSION IF NOT EXISTS timescaledb"
      '';
    };

    systemd.services.torq = rec {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" "postgresql.service" "torq-setup-db.service" ];
      after = requires;
      serviceConfig = nbLib.defaultHardening // {
        ExecStartPre = [
          (nbLib.script "torq-setup-config" ''
            <${configFile} sed "s|^password = \".*\"$|password = \"$(cat ${secretsDir}/torq-password)\"|" \
              > '${dataDir}/torq.toml'
          '')
        ];
        ExecStart = "${cfg.package}/bin/torq --config ${dataDir}/torq.toml start";
        StateDirectory = "torq";
        StateDirectoryMode = "770";
        WorkingDirectory = dataDir;
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    systemd.tmpfiles.rules = [
      "d  '${dataDir}'     0770 ${cfg.user} ${cfg.group} - -"
      "L+ '${dataDir}/web' -    -           -            - ${cfg.package}/web"
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets.torq-password.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.torq = ''
      makePasswordSecret torq-password
    '';
  };
}
