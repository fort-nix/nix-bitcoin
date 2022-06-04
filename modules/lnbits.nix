{ config, lib, pkgs, ... }:

with lib;
let
  options.services = {
    lnbits = {
      enable = mkEnableOption "LNbits, free and open-source lightning-network wallet/accounts system. ";
      listen = {
        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Address to listen on.";
        };
        port = mkOption {
          type = types.port;
          default = 5000;
          description = "Port to listen on.";
        };
        forceHttps = mkOption {
          type = types.bool;
          default = false;
          description = "Force HTTPS.";
        };
      };
      publicAddress = {
        host = mkOption {
          type = types.str;
          default = config.services.lnbits.listen.address;
          description = "Public facing hostname or ip, used when building callback URLs.";
        };
        port = mkOption {
          type = types.port;
          default = config.services.lnbits.listen.port;
          description = "Public facing port, used when building callback URLs.";
        };
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/lnbits";
        description = "The data directory for lnbits.";
      };
      lightningBackend = mkOption {
        type = types.nullOr (types.enum [ "clightning" "lnd" ]);
        default = null;
        description = "The lightning node implementation to use.";
      };
      database = {
        backend = mkOption {
          type = types.enum [ "sqlite" "postgres" ];
          default = "sqlite";
          description = "The database implementation used.";
        };

        postgresConfig = {
          databaseName = mkOption {
            type = types.str;
            default = "lnbits";
            description = "Database name.";
          };
        };
      };
      allowedUsers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of allowed users.";
      };
      adminUsers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of admin users.";
      };
      adminOnlyExtensions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extensions only admin can access.";
      };
      defaultWalletName = mkOption {
        type = types.str;
        default = "LNbits Wallet";
        description = "Default wallet name.";
      };
      adSpace = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "csv ad image filepaths or urls, extensions can choose to honor.";
      };
      hideApi = mkOption {
        type = types.bool;
        default = false;
        description = "Hides wallet api, extensions can choose to honor.";
      };
      disabledExtensions = mkOption {
        type = types.either types.str (types.listOf types.str);
        default = [];
        description = "Disable extensions for all users, use \"all\" to disable all extensions.";
      };
      serviceFee = mkOption {
        type = types.float;
        default = 0.0;
        description = "Service fee.";
      };
      siteTitle = mkOption {
        type = types.str;
        default = "LNbits";
        description = "Title shown on the website.";
      };
      siteTagline = mkOption {
        type = types.str;
        default = "free and open-source lightning wallet";
        description = "Tagline shown on the website.";
      };
      siteDescription = mkOption {
        type = types.str;
        default = "Some description about your service, will display if title is not 'LNbits'";
        description = "Description shown on the website.";
      };
      availableThemes = mkOption {
        type = types.listOf (types.enum [ "mint" "flamingo" "freedom" "salvador" "autumn" "monochrome" "classic" ]);
        default = [ "mint" "flamingo" "freedom" "salvador" "autumn" "monochrome" "classic"];
        description = "Theme options available.";
      };
      user = mkOption {
        type = types.str;
        default = "lnbits";
        description = "The user as which to run lnbits.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run lnbits.";
      };
    };
  };

  cfg = config.services.lnbits;
  nbLib = config.nix-bitcoin.lib;

  backendMap = {
    clightning = "CLightningWallet";
    lnd = "LndRestWallet";
  };

  inherit (config.services) bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.clightning.enable = mkIf (cfg.lightningBackend == "clightning") true;
    services.lnd = mkIf (cfg.lightningBackend == "lnd") {
      enable = true;
      macaroons.lnbits = {
        inherit (cfg) user;
        permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"read"},{"entity":"offchain","action":"read"},{"entity":"address","action":"read"},{"entity":"message","action":"read"},{"entity":"peers","action":"read"},{"entity":"signer","action":"read"},{"entity":"invoices","action":"read"},{"entity":"invoices","action":"write"},{"entity":"address","action":"write"}'';
      };
    };

    services.postgresql = mkIf (cfg.database.backend == "postgres") {
      enable = true;
      ensureDatabases = [ cfg.database.postgresConfig.databaseName ];
      ensureUsers = [
        {
          name = cfg.user;
          ensurePermissions."DATABASE ${cfg.database.postgresConfig.databaseName}" = "ALL PRIVILEGES";
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.lnbits = let
      configFile = builtins.toFile "lnbits-env" (''
        QUART_APP=lnbits.app:create_app()
        QUART_ENV=production

        HOST=${cfg.publicAddress.host}
        PORT=${toString cfg.publicAddress.port}

        LNBITS_DATA_FOLDER="${cfg.dataDir}/data"
        LNBITS_ALLOWED_USERS="${lib.concatStringsSep "," cfg.allowedUsers}"
        LNBITS_ADMIN_USERS="${lib.concatStringsSep "," cfg.adminUsers}"
        LNBITS_ADMIN_EXTENSIONS="${lib.concatStringsSep "," cfg.adminOnlyExtensions}"
        LNBITS_DEFAULT_WALLET_NAME="${cfg.defaultWalletName}"

      '' + optionalString (cfg.database.backend == "postgres") ''
        LNBITS_DATABASE_URL="postgresql://${cfg.user}@/${cfg.database.postgresConfig.databaseName}?host=/run/postgresql"
      '' + ''

        LNBITS_AD_SPACE="${lib.concatStringsSep "," cfg.adSpace}"
        LNBITS_HIDE_API=${boolToString cfg.hideApi}

        LNBITS_DISABLED_EXTENSIONS="${lib.concatStringsSep "," cfg.disabledExtensions}"

        LNBITS_FORCE_HTTPS=${boolToString cfg.listen.forceHttps}
        LNBITS_SERVICE_FEE="${toString cfg.serviceFee}"

        LNBITS_SITE_TITLE="${cfg.siteTitle}"
        LNBITS_SITE_TAGLINE="${cfg.siteTagline}"
        LNBITS_SITE_DESCRIPTION="${cfg.siteDescription}"
        LNBITS_THEME_OPTIONS="${lib.concatStringsSep "," cfg.availableThemes}"

        LNBITS_BACKEND_WALLET_CLASS="${
          if (builtins.isNull cfg.lightningBackend)
            then "VoidWallet"
            else backendMap."${cfg.lightningBackend}"
        }"
      '' + optionalString (cfg.lightningBackend == "clightning") ''
        CLIGHTNING_RPC="${config.services.clightning.dataDir}/${bitcoind.makeNetworkName "bitcoin" "regtest"}/lightning-rpc"
      '' + optionalString (cfg.lightningBackend == "lnd") ''
        LND_REST_ENDPOINT="https://${config.services.lnd.restAddress}:${toString config.services.lnd.restPort}/"
        LND_REST_CERT="${config.services.lnd.certPath}"
        LND_REST_MACAROON="/run/lnd/lnbits.macaroon"
      '');
    in let self = {
      wantedBy = [ "multi-user.target" ];
      requires = [ ]
                   ++ optional (builtins.elem cfg.lightningBackend (builtins.attrNames backendMap)) "${cfg.lightningBackend}.service"
                   ++ optional (cfg.database.backend == "postgres") "postgresql.service";

      after = self.requires;
      preStart = ''
        # create the directory for the SQLite db
        mkdir -p ${cfg.dataDir}/data

        # lnbits needs to write to its "static" directory the transpiled scss and the bundled css and js
        # since the nix store is read only, we need to copy the code in our datadir and run it from there
        rm -rf ${cfg.dataDir}/src
        cp -R ${config.nix-bitcoin.pkgs.lnbits}/lib ${cfg.dataDir}/src
        chmod 755 -R ${cfg.dataDir}/src

        install -m 600 ${configFile} '${cfg.dataDir}/src/.env'
      '';

      serviceConfig = nbLib.defaultHardening // {
        ExecStart = pkgs.writeShellScript "lnbits-exec-start" ''
          export UVICORN_HOST="${cfg.listen.address}"
          export UVICORN_PORT="${toString cfg.listen.port}"

          cd ${cfg.dataDir}/src
          exec ${config.nix-bitcoin.pkgs.lnbits}/bin/lnbits
        '';
        User = cfg.user;
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowAllIPAddresses;
    }; in self;

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [] ++ optional (cfg.lightningBackend == "clightning") config.services.clightning.user;
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = {};
  };
}
