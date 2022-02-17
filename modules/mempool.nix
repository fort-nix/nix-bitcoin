{ config, lib, pkgs, ... }:

with lib;
let
  options.services.mempool = {
    enable = mkEnableOption "Mempool, a fully featured Bitcoin visualizer, explorer, and API service.";
    # Use nginx address as services.mempool.address so onion-services.nix can pick up on it
    address = mkOption {
      type = types.str;
      default = if config.nix-bitcoin.netns-isolation.enable then
        config.nix-bitcoin.netns-isolation.netns.nginx.address
      else
        "localhost";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 12125; # random port for nginx
      description = "HTTP server port.";
    };
    backendAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "mempool-backend address.";
    };
    backendPort = mkOption {
      type = types.port;
      default = 8999;
      description = "Backend server port.";
    };
    electrumServer = mkOption {
      type = types.enum [ "electrs" "fulcrum" ];
      default = "electrs";
      description = "Electrum server implementation.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/mempool";
      description = "The data directory for Mempool.";
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
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.mempool;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;
  mysqlAddress = if config.nix-bitcoin.netns-isolation.enable then
    config.nix-bitcoin.netns-isolation.netns.mysql.address
  else
    "localhost";

  configFile = builtins.toFile "mempool-config"
    (builtins.toJSON
      {
        MEMPOOL = {
          NETWORK = "mainnet";
          BACKEND = "electrum";
          HTTP_PORT = cfg.backendPort;
          CACHE_DIR = "/run/mempool";
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
          HOST = mysqlAddress;
          PORT = config.services.mysql.port;
          DATABASE = "mempool";
          USERNAME = cfg.user;
          PASSWORD = "@mempoolDbPassword@";
        };
      }
    );

  inherit (config.services)
    bitcoind
    electrs
    fulcrum;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind.txindex = true;
    services.electrs.enable = mkIf (cfg.electrumServer == "electrs" ) true;
    services.fulcrum.enable = mkIf (cfg.electrumServer == "fulcrum" ) true;
    services.mysql = {
      enable = true;
      settings.mysqld.skip_name_resolve = true;
      package = pkgs.mariadb;
      initialDatabases = [{name = "mempool";}];
      initialScript = "${secretsDir}/mempool-db-initialScript";
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      # Create symlink to static website content
      "L+ /var/www/mempool/browser - - - - ${nbPkgs.mempool-frontend}"
    ];

    systemd.services.mempool = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "${cfg.electrumServer}.service" ];
      after = [ "${cfg.electrumServer}.service" "mysql.service" ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStartPre = [
          (nbLib.script "mempool-setup-config" ''
            <${configFile} sed \
              -e "s|@btcRpcPassword@|$(cat ${secretsDir}/bitcoin-rpcpassword-public)|" \
              -e "s|@mempoolDbPassword@|$(cat ${secretsDir}/mempool-db-password)|" \
              > '${cfg.dataDir}/config.json'
          '')
        ];
        ExecStart = "${nbPkgs.mempool-backend.workaround}/bin/mempool-backend";
        RuntimeDirectory = "mempool";
        # Show "mempool" instead of "node" in the journal
        SyslogIdentifier = "mempool";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // nbLib.nodejs;
    };

    services.nginx = {
      enable = true;
      enableReload = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      eventsConfig = ''
        multi_accept on;
      '';
      appendHttpConfig = ''
        map $http_accept_language $header_lang {
          default en-US;
          ~*^en-US en-US;
          ~*^en en-US;
          ~*^ar ar;
          ~*^ca ca;
          ~*^cs cs;
          ~*^de de;
          ~*^es es;
          ~*^fa fa;
          ~*^fr fr;
          ~*^ko ko;
          ~*^it it;
          ~*^he he;
          ~*^ka ka;
          ~*^hu hu;
          ~*^mk mk;
          ~*^nl nl;
          ~*^ja ja;
          ~*^nb nb;
          ~*^pl pl;
          ~*^pt pt;
          ~*^ro ro;
          ~*^ru ru;
          ~*^sl sl;
          ~*^fi fi;
          ~*^sv sv;
          ~*^th th;
          ~*^tr tr;
          ~*^uk uk;
          ~*^vi vi;
          ~*^zh zh;
          ~*^hi hi;
        }

        map $cookie_lang $lang {
          default $header_lang;
          ~*^en-US en-US;
          ~*^en en-US;
          ~*^ar ar;
          ~*^ca ca;
          ~*^cs cs;
          ~*^de de;
          ~*^es es;
          ~*^fa fa;
          ~*^fr fr;
          ~*^ko ko;
          ~*^it it;
          ~*^he he;
          ~*^ka ka;
          ~*^hu hu;
          ~*^mk mk;
          ~*^nl nl;
          ~*^ja ja;
          ~*^nb nb;
          ~*^pl pl;
          ~*^pt pt;
          ~*^ro ro;
          ~*^ru ru;
          ~*^sl sl;
          ~*^fi fi;
          ~*^sv sv;
          ~*^th th;
          ~*^tr tr;
          ~*^uk uk;
          ~*^vi vi;
          ~*^zh zh;
          ~*^hi hi;
        }
      '';
      virtualHosts."mempool" = {
        root = "/var/www/mempool/browser";
        serverName = "_";
        listen = [ { addr = cfg.address; port = cfg.port; } ];
        extraConfig = ''
          add_header Cache-Control "public, no-transform";

          add_header Vary Accept-Language;
          add_header Vary Cookie;

          location / {
                  try_files /$lang/$uri /$lang/$uri/ $uri $uri/ /en-US/$uri @index-redirect;
                  expires 10m;
          }
          location /resources {
                  try_files /$lang/$uri /$lang/$uri/ $uri $uri/ /en-US/$uri @index-redirect;
                  expires 1h;
          }
          location @index-redirect {
                  rewrite (.*) /$lang/index.html;
          }

          location ~ ^/(ar|bg|bs|ca|cs|da|de|et|el|es|eo|eu|fa|fr|gl|ko|hr|id|it|he|ka|lv|lt|hu|mk|ms|nl|ja|nb|nn|pl|pt|pt-BR|ro|ru|sk|sl|sr|sh|fi|sv|th|tr|uk|vi|zh|hi)/resources/ {
                  rewrite ^/[a-zA-Z-]*/resources/(.*) /en-US/resources/$1;
          }
          location ~ ^/(ar|bg|bs|ca|cs|da|de|et|el|es|eo|eu|fa|fr|gl|ko|hr|id|it|he|ka|lv|lt|hu|mk|ms|nl|ja|nb|nn|pl|pt|pt-BR|ro|ru|sk|sl|sr|sh|fi|sv|th|tr|uk|vi|zh|hi)/ {
                  try_files $uri $uri/ /$1/index.html =404;
          }

          location = /api {
                  try_files $uri $uri/ /en-US/index.html =404;
          }
          location = /api/ {
                  try_files $uri $uri/ /en-US/index.html =404;
          }

          location /api/v1/ws {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/;
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "Upgrade";
          }
          location /api/v1 {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/api/v1;
          }
          location /api/ {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/api/v1/;
          }

          location /ws {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/;
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "Upgrade";
          }
        '';
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets.mempool-db-initialScript.user = config.services.mysql.user;
    nix-bitcoin.secrets.mempool-db-password.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.mempool = ''
      makePasswordSecret mempool-db-password
      if [[ mempool-db-password -nt mempool-db-initialScript ]]; then
         echo "grant all on mempool.* to '${cfg.user}'@'${cfg.backendAddress}' identified by '$(cat mempool-db-password)'" > mempool-db-initialScript
      fi
    '';
  };
}
