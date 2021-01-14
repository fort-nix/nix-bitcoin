{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;
  inherit (config) nix-bitcoin-services;
  nbPkgs = config.nix-bitcoin.pkgs;
in {
  options.services = {
    nbxplorer = {
      package = mkOption {
        type = types.package;
        default = nbPkgs.nbxplorer;
        description = "The package providing nbxplorer binaries.";
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
      bind = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "The address on which to bind.";
      };
      port = mkOption {
        type = types.port;
        default = 24444;
        description = "Port on which to bind.";
      };
      enable = mkOption {
        # This option is only used by netns-isolation
        internal = true;
        default = cfg.btcpayserver.enable;
      };
      enforceTor = nix-bitcoin-services.enforceTor;
    };

    btcpayserver = {
      enable = mkEnableOption "btcpayserver";
      package = mkOption {
        type = types.package;
        default = nbPkgs.btcpayserver;
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
      bind = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "The address on which to bind.";
      };
      port = mkOption {
        type = types.port;
        default = 23000;
        description = "Port on which to bind.";
      };
      lightningBackend = mkOption {
        type = types.nullOr (types.enum [ "clightning" "lnd" ]);
        default = null;
        description = "The lightning node implementation to use.";
      };
      rootpath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "btcpayserver";
        description = "The prefix for root-relative btcpayserver URLs.";
      };
      enforceTor = nix-bitcoin-services.enforceTor;
    };
  };

  config = mkIf cfg.btcpayserver.enable {
    services.bitcoind.enable = true;
    services.clightning.enable = mkIf (cfg.btcpayserver.lightningBackend == "clightning") true;
    services.lnd.enable = mkIf (cfg.btcpayserver.lightningBackend == "lnd") true;

    systemd.tmpfiles.rules = [
      "d '${cfg.nbxplorer.dataDir}' 0770 ${cfg.nbxplorer.user} ${cfg.nbxplorer.group} - -"
      "d '${cfg.btcpayserver.dataDir}' 0770 ${cfg.btcpayserver.user} ${cfg.btcpayserver.group} - -"
    ];

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "btcpaydb" ];
      ensureUsers = [{
        name = "${cfg.btcpayserver.user}";
        ensurePermissions."DATABASE btcpaydb" = "ALL PRIVILEGES";
      }];
    };

    systemd.services.nbxplorer = let
      configFile = builtins.toFile "config" ''
        network=${config.services.bitcoind.network}
        btcrpcuser=${cfg.bitcoind.rpc.users.btcpayserver.name}
        btcrpcurl=http://${config.services.bitcoind.rpc.address}:${toString cfg.bitcoind.rpc.port}
        btcnodeendpoint=${config.services.bitcoind.address}:${toString config.services.bitcoind.port}
        bind=${cfg.nbxplorer.bind}
        port=${toString cfg.nbxplorer.port}
      '';
    in {
      description = "Run nbxplorer";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        install -m 600 ${configFile} ${cfg.nbxplorer.dataDir}/settings.config
        echo "btcrpcpassword=$(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword-btcpayserver)" \
          >> '${cfg.nbxplorer.dataDir}/settings.config'
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = ''
          ${cfg.nbxplorer.package}/bin/nbxplorer --conf=${cfg.nbxplorer.dataDir}/settings.config \
            --datadir=${cfg.nbxplorer.dataDir}
        '';
        User = cfg.nbxplorer.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.nbxplorer.dataDir;
        MemoryDenyWriteExecute = "false";
      } // (if cfg.nbxplorer.enforceTor
        then nix-bitcoin-services.allowTor
        else nix-bitcoin-services.allowAnyIP
      );
    };

    systemd.services.btcpayserver = let
      configFile = builtins.toFile "config" (''
        network=${config.services.bitcoind.network}
        postgres=User ID=${cfg.btcpayserver.user};Host=/run/postgresql;Database=btcpaydb
        socksendpoint=${cfg.tor.client.socksListenAddress}
        btcexplorerurl=http://${cfg.nbxplorer.bind}:${toString cfg.nbxplorer.port}/
        btcexplorercookiefile=${cfg.nbxplorer.dataDir}/${config.services.bitcoind.makeNetworkName "Main" "RegTest"}/.cookie
        bind=${cfg.btcpayserver.bind}
        ${optionalString (cfg.btcpayserver.rootpath != null) "rootpath=${cfg.btcpayserver.rootpath}"}
        port=${toString cfg.btcpayserver.port}
      '' + optionalString (cfg.btcpayserver.lightningBackend == "clightning") ''
        btclightning=type=clightning;server=unix:///${cfg.clightning.dataDir}/bitcoin/lightning-rpc
      '');
      lndConfig =
        "btclightning=type=lnd-rest;" +
        "server=https://${toString cfg.lnd.listen}:${toString cfg.lnd.restPort}/;" +
        "macaroonfilepath=/run/lnd/btcpayserver.macaroon;" +
        "certthumbprint=";
    in let self = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "nbxplorer.service" ]
                 ++ optional (cfg.btcpayserver.lightningBackend != null) "${cfg.btcpayserver.lightningBackend}.service";
      after = self.requires;
      preStart = ''
        install -m 600 ${configFile} ${cfg.btcpayserver.dataDir}/settings.config
        ${optionalString (cfg.btcpayserver.lightningBackend == "lnd") ''
          {
            echo -n "${lndConfig}";
            ${pkgs.openssl}/bin/openssl x509 -noout -fingerprint -sha256 -in ${config.nix-bitcoin.secretsDir}/lnd-cert \
              | sed -e 's/.*=//;s/://g';
          } >> ${cfg.btcpayserver.dataDir}/settings.config
        ''}
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = ''
          ${cfg.btcpayserver.package}/bin/btcpayserver --conf=${cfg.btcpayserver.dataDir}/settings.config \
            --datadir=${cfg.btcpayserver.dataDir}
        '';
        User = cfg.btcpayserver.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.btcpayserver.dataDir;
        MemoryDenyWriteExecute = "false";
      } // (if cfg.btcpayserver.enforceTor
        then nix-bitcoin-services.allowTor
        else nix-bitcoin-services.allowAnyIP
      );
    }; in self;

    services.lnd.macaroons.btcpayserver = mkIf (cfg.btcpayserver.lightningBackend == "lnd") {
      inherit (cfg.btcpayserver) user;
      permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"read"},{"entity":"offchain","action":"read"},{"entity":"address","action":"read"},{"entity":"message","action":"read"},{"entity":"peers","action":"read"},{"entity":"signer","action":"read"},{"entity":"invoices","action":"read"},{"entity":"invoices","action":"write"},{"entity":"address","action":"write"}'';
    };

    users.users.${cfg.nbxplorer.user} = {
      description = "nbxplorer user";
      group = cfg.nbxplorer.group;
      extraGroups = [ "bitcoinrpc" ];
      home = cfg.nbxplorer.dataDir;
    };
    users.groups.${cfg.nbxplorer.group} = {};
    users.users.${cfg.btcpayserver.user} = {
      description = "btcpayserver user";
      group = cfg.btcpayserver.group;
      extraGroups = [ "nbxplorer" ]
                    ++ optional (cfg.btcpayserver.lightningBackend == "clightning") cfg.clightning.user;
      home = cfg.btcpayserver.dataDir;
    };
    users.groups.${cfg.btcpayserver.group} = {};

    services.bitcoind.rpc.users.btcpayserver = {
      passwordHMACFromFile = true;
      rpcwhitelist = cfg.bitcoind.rpc.users.public.rpcwhitelist ++ [
        "setban"
        "generatetoaddress"
        "getpeerinfo"
      ];
    };
    nix-bitcoin.secrets.bitcoin-rpcpassword-btcpayserver = {
      user = "bitcoin";
      group = "nbxplorer";
    };
    nix-bitcoin.secrets.bitcoin-HMAC-btcpayserver.user = "bitcoin";
  };
}
