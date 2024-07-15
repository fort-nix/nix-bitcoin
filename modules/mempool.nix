{ config, lib, pkgs, ... }:

with lib;
let
  options.services = {
    mempool = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable Mempool, a fully featured Bitcoin visualizer, explorer, and API service.

          Note: Mempool enables `txindex` in bitcoind (this is a requirement).

          This module has two components:
          - A backend service (systemd service `mempool`)

          - An optional web interface run by nginx, defined by options `services.mempool.frontend.*`.
            The frontend is enabled by default when mempool is enabled.
            For details, see `services.mempool.frontend.enable`.
        '';
      };

      frontend = {
        enable = mkOption {
          type = types.bool;
          default = cfg.enable;
          description = ''
            Enable the mempool frontend (web interface).
            This starts a simple nginx instance, configured for local usage with
            settings similar to the `mempool/frontend` Docker image.

            IMPORTANT:
            If you want to expose the mempool frontend to the internet, you
            should create a custom nginx config that includes TLS, backend caching, rate limiting
            and performance tuning.
            For this task, reuse the config snippets from option `services.mempool.frontend.nginxConfig`.
            See also: https://github.com/fort-nix/nixbitcoin.org/blob/master/website/mempool.nix,
            which contains a mempool nginx config for public hosting (running at
            https://mempool.nixbitcoin.org).
          '';
        };
        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "HTTP server address.";
        };
        port = mkOption {
          type = types.port;
          default = 60845; # A random private port
          description = "HTTP server port.";
        };
        staticContentRoot = mkOption {
          type = types.path;
          default = nbPkgs.mempool-frontend;
          defaultText = "config.nix-bitcoin.pkgs.mempool-frontend";
          description = "
            Path of the static frontend content root.
          ";
        };
        nginxConfig = mkOption {
          readOnly = true;
          default = frontend.nginxConfig;
          defaultText = "(See source)";
          description = "
            An attrset of nginx config snippets for assembling a custom
            mempool nginx config.
            For details, see the source comments at the point of definition.
          ";
        };
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Mempool backend address.";
      };
      port = mkOption {
        type = types.port;
        default = 8999;
        description = "Mempool backend port.";
      };
      electrumServer = mkOption {
        type = types.enum [ "electrs" "fulcrum" ];
        default = "electrs";
        description = ''
          The Electrum server to use for fetching address information.

          Possible options:
          - electrs:
            Small database size, slow when querying new addresses.
          - fulcrum:
            Large database size, quickly serves arbitrary address queries.
        '';
      };
      settings = mkOption {
        type = with types; attrsOf (attrsOf anything);
        example = {
          MEMPOOL = {
            POLL_RATE_MS = 3000;
            STDOUT_LOG_MIN_PRIORITY = "debug";
          };
          PRICE_DATA_SERVER = {
            CLEARNET_URL = "https://myserver.org/prices";
          };
        };
        description = ''
          Mempool backend settings.
          See here for possible options:
          https://github.com/mempool/mempool/blob/master/backend/src/config.ts
        '';
      };
      database = {
        name = mkOption {
          type = types.str;
          default = "mempool";
          description = "Database name.";
        };
      };
      package = mkOption {
        type = types.package;
        default = nbPkgs.mempool-backend;
        defaultText = "config.nix-bitcoin.pkgs.mempool-backend";
        description = "The package providing mempool binaries.";
      };
      user = mkOption {
        type = types.str;
        default = "mempool";
        description = "The user as which to run Mempool.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run Mempool.";
      };
      tor = nbLib.tor;
    };

    # Internal read-only options used by `./nodeinfo.nix` and `./onion-services.nix`
    mempool-frontend = let
      mkAlias = default: mkOption {
        internal = true;
        readOnly = true;
        inherit default;
      };
    in {
      enable = mkAlias cfg.frontend.enable;
      address = mkAlias cfg.frontend.address;
      port = mkAlias cfg.frontend.port;
    };
  };

  cfg = config.services.mempool;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  configFile = builtins.toFile "mempool-config" (builtins.toJSON cfg.settings);
  cacheDir = "/var/cache/mempool";

  inherit (config.services)
    bitcoind
    electrs
    fulcrum;

  torSocket = config.services.tor.client.socksListenAddress;

  # See the `services.nginx` definition further below below
  # on how to use these snippets.
  frontend.nginxConfig = {
    # This must be added to `services.nginx.commonHttpConfig` when
    # `mempool/location-static.conf` is used
    httpConfig = ''
      include ${nbPkgs.mempool-nginx-conf}/mempool/http-language.conf;
    '';

    # This should be added to `services.nginx.virtualHosts.<mempool server name>.extraConfig`
    staticContent = ''
      index index.html;

      add_header Cache-Control "public, no-transform";
      add_header Vary Accept-Language;
      add_header Vary Cookie;

      include ${nbPkgs.mempool-nginx-conf}/mempool/location-static.conf;

      # Redirect /api to /docs/api
      location = /api {
        return 308 https://$host/docs/api;
      }
      location = /api/ {
        return 308 https://$host/docs/api;
      }
    '';

    # This should be added to `services.nginx.virtualHosts.<mempool server name>.extraConfig`
    proxyApi = let
      backend = "http://${nbLib.addressWithPort cfg.address cfg.port}";
    in ''
      location /api/ {
          proxy_pass ${backend}/api/v1/;
      }
      location /api/v1 {
          proxy_pass ${backend};
      }
      # Websocket API
      location /api/v1/ws {
          proxy_pass ${backend};

          # Websocket header settings
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "Upgrade";

          # Relevant settings from `recommendedProxyConfig` (nixos/nginx/default.nix)
          # (In the above api locations, this are inherited from the parent scope)
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }
    '';
  };

in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind.txindex = true;
    services.electrs.enable = mkIf (cfg.electrumServer == "electrs" ) true;
    services.fulcrum.enable = mkIf (cfg.electrumServer == "fulcrum" ) true;
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.user;
          ensurePermissions."${cfg.database.name}.*" = "ALL PRIVILEGES";
        }
      ];
    };

    # Available options:
    # https://github.com/mempool/mempool/blob/master/backend/src/config.ts
    services.mempool.settings = {
      MEMPOOL = {
        # mempool doesn't support regtest
        NETWORK = "mainnet";
        BACKEND = "electrum";
        HTTP_PORT = cfg.port;
        CACHE_DIR = "${cacheDir}/cache";
        STDOUT_LOG_MIN_PRIORITY = mkDefault "info";
      };
      CORE_RPC = {
        HOST = bitcoind.rpc.address;
        PORT = bitcoind.rpc.port;
        USERNAME = bitcoind.rpc.users.public.name;
        PASSWORD = "@btcRpcPassword@";
      };
      ELECTRUM = let
        server = config.services.${cfg.electrumServer};
      in {
        HOST = server.address;
        PORT = server.port;
        TLS_ENABLED = false;
      };
      DATABASE = {
        ENABLED = true;
        DATABASE = cfg.database.name;
        SOCKET = "/run/mysqld/mysqld.sock";
      };
    } // optionalAttrs (cfg.tor.proxy) {
      # Use Tor for rate fetching
      SOCKS5PROXY = {
        ENABLED = true;
        USE_ONION = true;
        HOST = torSocket.addr;
        PORT = torSocket.port;
      };
    };

    systemd.services.mempool = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "${cfg.electrumServer}.service" ];
      after = [ "${cfg.electrumServer}.service" "mysql.service" ];
      preStart = ''
        mkdir -p '${cacheDir}/cache'
        <${configFile} sed \
          -e "s|@btcRpcPassword@|$(cat ${secretsDir}/bitcoin-rpcpassword-public)|" \
          > '${cacheDir}/config.json'
      '';
      environment.MEMPOOL_CONFIG_FILE = "${cacheDir}/config.json";
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${cfg.package}/bin/mempool-backend";
        CacheDirectory = "mempool";
        CacheDirectoryMode = "770";
        # Show "mempool" instead of "node" in the journal
        SyslogIdentifier = "mempool";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // nbLib.nodejs;
    };

    services.nginx = mkIf cfg.frontend.enable {
      enable = true;
      enableReload = true;
      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      commonHttpConfig = frontend.nginxConfig.httpConfig;
      virtualHosts."mempool" = {
        serverName = "_";
        listen = [ { addr = cfg.frontend.address; port = cfg.frontend.port; } ];
        root = cfg.frontend.staticContentRoot;
        extraConfig =
          frontend.nginxConfig.staticContent +
          frontend.nginxConfig.proxyApi;
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}
