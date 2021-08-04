{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
in {
  options.services = {
    nbxplorer = {
      package = mkOption {
        type = types.package;
        default = nbPkgs.nbxplorer;
        description = "The package providing nbxplorer binaries.";
      };
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen on.";
      };
      port = mkOption {
        type = types.port;
        default = 24444;
        description = "Port to listen on.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/nbxplorer";
        description = "The data directory for nbxplorer.";
      };
      user = mkOption {
        type = types.str;
        default = "nbxplorer";
        description = "The user as which to run nbxplorer.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.nbxplorer.user;
        description = "The group as which to run nbxplorer.";
      };
      enable = mkOption {
        # This option is only used by netns-isolation
        internal = true;
        default = cfg.btcpayserver.enable;
      };
      enforceTor = nbLib.enforceTor;
    };

    btcpayserver = {
      enable = mkEnableOption "btcpayserver";
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen on.";
      };
      port = mkOption {
        type = types.port;
        default = 23000;
        description = "Port to listen on.";
      };
      package = mkOption {
        type = types.package;
        default = if cfg.btcpayserver.lbtc then
                    nbPkgs.btcpayserver.override { altcoinSupport = true; }
                  else
                    nbPkgs.btcpayserver;
        description = "The package providing btcpayserver binaries.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/btcpayserver";
        description = "The data directory for btcpayserver.";
      };
      user = mkOption {
        type = types.str;
        default = "btcpayserver";
        description = "The user as which to run btcpayserver.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.btcpayserver.user;
        description = "The group as which to run btcpayserver.";
      };
      lightningBackend = mkOption {
        type = types.nullOr (types.enum [ "clightning" "lnd" ]);
        default = null;
        description = "The lightning node implementation to use.";
      };
      lbtc = mkOption {
        type = types.bool;
        default = false;
        description = "Enable liquid support in btcpayserver.";
      };
      rootpath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "btcpayserver";
        description = "The prefix for root-relative btcpayserver URLs.";
      };
      enforceTor = nbLib.enforceTor;
    };
  };

  config = mkIf cfg.btcpayserver.enable {
    services.bitcoind.enable = true;
    services.clightning.enable = mkIf (cfg.btcpayserver.lightningBackend == "clightning") true;
    services.lnd.enable = mkIf (cfg.btcpayserver.lightningBackend == "lnd") true;
    services.liquidd.enable = mkIf cfg.btcpayserver.lbtc true;

    services.bitcoind.rpc.users.btcpayserver = {
      passwordHMACFromFile = true;
      rpcwhitelist = cfg.bitcoind.rpc.users.public.rpcwhitelist ++ [
        "setban"
        "generatetoaddress"
        "getpeerinfo"
      ];
    };

    services.lnd.macaroons.btcpayserver = mkIf (cfg.btcpayserver.lightningBackend == "lnd") {
      inherit (cfg.btcpayserver) user;
      permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"read"},{"entity":"offchain","action":"read"},{"entity":"address","action":"read"},{"entity":"message","action":"read"},{"entity":"peers","action":"read"},{"entity":"signer","action":"read"},{"entity":"invoices","action":"read"},{"entity":"invoices","action":"write"},{"entity":"address","action":"write"}'';
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "btcpaydb" ];
      ensureUsers = [{
        name = cfg.btcpayserver.user;
        ensurePermissions."DATABASE btcpaydb" = "ALL PRIVILEGES";
      }];
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.nbxplorer.dataDir}' 0770 ${cfg.nbxplorer.user} ${cfg.nbxplorer.group} - -"
      "d '${cfg.btcpayserver.dataDir}' 0770 ${cfg.btcpayserver.user} ${cfg.btcpayserver.group} - -"
    ];

    systemd.services.nbxplorer = let
      configFile = builtins.toFile "config" ''
        network=${config.services.bitcoind.network}
        btcrpcuser=${cfg.bitcoind.rpc.users.btcpayserver.name}
        btcrpcurl=http://${config.services.bitcoind.rpc.address}:${toString cfg.bitcoind.rpc.port}
        btcnodeendpoint=${config.services.bitcoind.address}:${toString config.services.bitcoind.port}
        bind=${cfg.nbxplorer.address}
        port=${toString cfg.nbxplorer.port}
        ${optionalString cfg.btcpayserver.lbtc ''
          chains=btc,lbtc
          lbtcrpcuser=${cfg.liquidd.rpcuser}
          lbtcrpcurl=http://${cfg.liquidd.rpc.address}:${toString cfg.liquidd.rpc.port}
          lbtcnodeendpoint=${cfg.liquidd.address}:${toString cfg.liquidd.port}
        ''}
      '';
    in {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        install -m 600 ${configFile} '${cfg.nbxplorer.dataDir}/settings.config'
        {
          echo "btcrpcpassword=$(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword-btcpayserver)"
          ${optionalString cfg.btcpayserver.lbtc ''
            echo "lbtcrpcpassword=$(cat ${config.nix-bitcoin.secretsDir}/liquid-rpcpassword)"
          ''}
        } >> '${cfg.nbxplorer.dataDir}/settings.config'
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = ''
          ${cfg.nbxplorer.package}/bin/nbxplorer --conf=${cfg.nbxplorer.dataDir}/settings.config \
            --datadir=${cfg.nbxplorer.dataDir}
        '';
        User = cfg.nbxplorer.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.nbxplorer.dataDir;
        MemoryDenyWriteExecute = "false";
      } // nbLib.allowedIPAddresses cfg.nbxplorer.enforceTor;
    };

    systemd.services.btcpayserver = let
      nbExplorerUrl = "http://${cfg.nbxplorer.address}:${toString cfg.nbxplorer.port}/";
      nbExplorerCookie = "${cfg.nbxplorer.dataDir}/${config.services.bitcoind.makeNetworkName "Main" "RegTest"}/.cookie";
      configFile = builtins.toFile "config" (''
        network=${config.services.bitcoind.network}
        bind=${cfg.btcpayserver.address}
        port=${toString cfg.btcpayserver.port}
        socksendpoint=${cfg.tor.client.socksListenAddress}
        btcexplorerurl=${nbExplorerUrl}
        btcexplorercookiefile=${nbExplorerCookie}
        postgres=User ID=${cfg.btcpayserver.user};Host=/run/postgresql;Database=btcpaydb
        ${optionalString (cfg.btcpayserver.rootpath != null) "rootpath=${cfg.btcpayserver.rootpath}"}
      '' + optionalString (cfg.btcpayserver.lightningBackend == "clightning") ''
        btclightning=type=clightning;server=unix:///${cfg.clightning.dataDir}/bitcoin/lightning-rpc
      '' + optionalString cfg.btcpayserver.lbtc ''
        chains=btc,lbtc
        lbtcexplorerurl=${nbExplorerUrl}
        lbtcexplorercookiefile=${nbExplorerCookie}
      '');
      lndConfig =
        "btclightning=type=lnd-rest;" +
        "server=https://${cfg.lnd.restAddress}:${toString cfg.lnd.restPort}/;" +
        "macaroonfilepath=/run/lnd/btcpayserver.macaroon;" +
        "certthumbprint=";
    in let self = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "nbxplorer.service" "postgresql.service" ]
                 ++ optional (cfg.btcpayserver.lightningBackend != null) "${cfg.btcpayserver.lightningBackend}.service";
      after = self.requires;
      preStart = ''
        install -m 600 ${configFile} '${cfg.btcpayserver.dataDir}/settings.config'
        ${optionalString (cfg.btcpayserver.lightningBackend == "lnd") ''
          {
            echo -n "${lndConfig}";
            ${pkgs.openssl}/bin/openssl x509 -noout -fingerprint -sha256 -in ${config.nix-bitcoin.secretsDir}/lnd-cert \
              | sed -e 's/.*=//;s/://g';
          } >> '${cfg.btcpayserver.dataDir}/settings.config'
        ''}
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = ''
          ${cfg.btcpayserver.package}/bin/btcpayserver --conf=${cfg.btcpayserver.dataDir}/settings.config \
            --datadir=${cfg.btcpayserver.dataDir}
        '';
        User = cfg.btcpayserver.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.btcpayserver.dataDir;
        MemoryDenyWriteExecute = "false";
      } // nbLib.allowedIPAddresses cfg.btcpayserver.enforceTor;
    }; in self;

    users.users.${cfg.nbxplorer.user} = {
      isSystemUser = true;
      group = cfg.nbxplorer.group;
      extraGroups = [ "bitcoinrpc-public" ]
                    ++ optional cfg.btcpayserver.lbtc cfg.liquidd.group;
      home = cfg.nbxplorer.dataDir;
    };
    users.groups.${cfg.nbxplorer.group} = {};
    users.users.${cfg.btcpayserver.user} = {
      isSystemUser = true;
      group = cfg.btcpayserver.group;
      extraGroups = [ cfg.nbxplorer.group ]
                    ++ optional (cfg.btcpayserver.lightningBackend == "clightning") cfg.clightning.user;
      home = cfg.btcpayserver.dataDir;
    };
    users.groups.${cfg.btcpayserver.group} = {};

    nix-bitcoin.secrets = {
      bitcoin-rpcpassword-btcpayserver = {
        user = cfg.bitcoind.user;
        group = cfg.nbxplorer.group;
      };
      bitcoin-HMAC-btcpayserver.user = cfg.bitcoind.user;
    };
  };
}
