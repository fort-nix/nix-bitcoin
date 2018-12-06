{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin-webindex;
  indexFile = pkgs.writeText "index.html" ''
    <html>
      <body>
        <p>
          <h1>
            nix-bitcoin
          </h1>
        </p>
        <p>
        <h2>
          <a href="store/">store</a>
        </h2>
        </p>
        <p>
        <h3>
          lightning node: CLIGHTNING_ID
        </h3>
        </p>
      </body>
    </html>
  '';
  createWebIndex = pkgs.writeText "make-index.sh" ''
    set -e
    mkdir -p /var/www/
    cp ${indexFile} /var/www/index.html
    chown -R nginx /var/www/
    nodeinfo
    . <(nodeinfo)
    sed -i "s/CLIGHTNING_ID/$CLIGHTNING_ID/g" /var/www/index.html
  '';
in {
  options.services.nixbitcoin-webindex = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the webindex service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."_" = {
        root = "/var/www";
        extraConfig = ''
          location /store/ {
            proxy_pass http://127.0.0.1:${toString config.services.nanopos.port};
            rewrite /store/(.*) /$1 break;
          }
        '';
      };
    };
    services.tor.hiddenServices.nginx = {
      map = [{
        port = 80;
      } {
        port = 443;
      }];
      version = 3;
    };

    # create-web-index
    systemd.services.create-web-index = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      after = [ "nodeinfo.service" ];
      path  = [ pkgs.nodeinfo pkgs.clightning pkgs.jq pkgs.sudo ];
      serviceConfig = {
        ExecStart="${pkgs.bash}/bin/bash ${createWebIndex}";
        User = "root";
        Type = "simple";
        RemainAfterExit="yes";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };
}
