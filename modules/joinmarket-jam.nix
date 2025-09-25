{ config, lib, pkgs, ... }:

with lib;
let
  options.services.joinmarket-jam = {
    enable = mkEnableOption "Enable the JoinMarket Jam web interface.";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = mdDoc "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 61851;
      description = mdDoc "HTTP server port.";
    };
    staticContentRoot = mkOption {
      type = types.path;
      default = nbPkgs.joinmarket-jam;
      defaultText = "config.nix-bitcoin.pkgs.joinmarket-jam";
      description = mdDoc "Path of the static content root.";
    };
    nginxConfig = mkOption {
      readOnly = true;
      default = nginxConfig;
      defaultText = "(See source)";
      description = mdDoc ''
        An attrset of nginx config snippets for assembling a custom
        joinmarket's jam nginx config.
      '';
    };
    package = mkOption {
      type = types.package;
      default = nbPkgs.joinmarket-jam;
      defaultText = "config.nix-bitcoin.pkgs.joinmarket-jam";
      description = mdDoc "The package providing joinmarket's jam files.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket-jam";
      description = mdDoc "The user as which to run Jam.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = mdDoc "The group as which to run Jam.";
    };
    tor.enforce = nbLib.tor.enforce;

    #settings = mkOption {
    #};
  };

  cfg = config.services.joinmarket-jam;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;

  inherit (config.services) joinmarket-ob-watcher joinmarket-jmwalletd;

  # Nginx configuration is highgly inspired by official jam-docker ui-only container.
  # https://github.com/joinmarket-webui/jam-docker/tree/master/ui-only/nginx
  nginxConfig = {
    staticContent = ''
      index index.html;

      add_header Cache-Control "public, no-transform";
      add_header Vary Accept-Language;
      add_header Vary Cookie;
    '';

    proxyApi = let
      jmwalletd_api_backend = "https://${nbLib.addressWithPort joinmarket-jmwalletd.address joinmarket-jmwalletd.port}";
      jmwalletd_wss_backend = "https://${nbLib.addressWithPort joinmarket-jmwalletd.address joinmarket-jmwalletd.wssPort}/";
      ob_watcher_backend = "http://${nbLib.addressWithPort joinmarket-ob-watcher.address joinmarket-ob-watcher.port}";
    in ''
      location / {
        #include /etc/nginx/snippets/proxy-params.conf;

        try_files $uri $uri/ /index.html;
        add_header Cache-Control no-cache;
      }
      location /api/ {
          proxy_pass ${jmwalletd_api_backend};

          #include /etc/nginx/snippets/proxy-params.conf;

          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_set_header Authorization $http_x_jm_authorization;
          proxy_set_header x-jm-authorization "";
          proxy_read_timeout 300s;
          proxy_connect_timeout 300s;
      }
      location = /jmws {
          proxy_pass ${jmwalletd_wss_backend};

          #include /etc/nginx/snippets/proxy-params.conf;

          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "Upgrade";
          proxy_set_header Authorization "";

          # allow 10m without socket activity (default is 60 sec)
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
      }
      location /obwatch/ {
          proxy_pass ${ob_watcher_backend};

          #include /etc/nginx/snippets/proxy-params.conf;

          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_read_timeout 300s;
          proxy_connect_timeout 300s;
      }
      location = /jam/internal/auth {
          internal;
          proxy_pass http://$server_addr:$server_port/api/v1/session;

          #if ($jm_auth_present != 1) {
          #    return 401;
          #}

          #include /etc/nginx/snippets/proxy-params.conf;

          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
      }
      location = /jam/api/v0/features {
          auth_request /jam/internal/auth;
          default_type application/json;
          return 200 '{ "features": { "logs": false } }';
      }
      location /jam/api/v0/log/ {
          auth_request /jam/internal/auth;
          return 501; # Not Implemented
      }
    '';
  };

in {
  inherit options;

  config = mkIf cfg.enable {
    services = {
      joinmarket-ob-watcher.enable = true;
      joinmarket-jmwalletd.enable = true;

      nginx = {
        enable = true;
        enableReload = true;
        recommendedBrotliSettings = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        # TODO: Use this to define "map"? See: https://github.com/joinmarket-webui/jam-docker/blob/master/ui-only/nginx/templates/default.conf.template#L20
        #commonHttpConfig = nginxConfig.httpConfig;
        virtualHosts."joinmarket-jam" = {
          serverName = "_";
          listen = [ { addr = cfg.address; port = cfg.port; } ];
          root = cfg.staticContentRoot;
          extraConfig = nginxConfig.staticContent + nginxConfig.proxyApi;
        };
      };
    };

    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
      };
      groups.${cfg.group} = {};
    };
  };
}
