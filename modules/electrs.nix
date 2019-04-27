{ config, lib, pkgs, ... }:

with lib;

let
  nix-bitcoin-services = import ./nix-bitcoin-services.nix;
  cfg = config.services.electrs;
  index-batch-size = "${if cfg.high-memory then "" else "--index-batch-size=10"}";
  jsonrpc-import = "${if cfg.high-memory then "" else "--jsonrpc-import"}";
in {
  options.services.electrs = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the electrs service will be installed.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/electrs";
      description = "The data directory for electrs.";
    };
    high-memory = mkOption {
      type = types.bool;
      default = false;
      description = ''
      If enabled, the electrs service will sync faster on high-memory systems (≥ 8GB).
      '';
    };
    port = mkOption {
        type = types.ints.u16;
        default = 50001;
        description = "Override the default port on which to listen for connections.";
    };
    onionport = mkOption {
        type = types.ints.u16;
        default = 50002;
        description = "Override the default port on which to listen for connections.";
    };
    nginxport = mkOption {
        type = types.ints.u16;
        default = 50003;
        description = "Override the default port on which to listen for connections.";
    };
  };

  config = mkIf cfg.enable {
    users.users.electrs = {
        description = "electrs User";
        group = "electrs";
        extraGroups = [ "bitcoinrpc" "keys" "bitcoin"];
        home = cfg.dataDir;
    };
    users.groups.electrs = {
      name = "electrs";
    };   

    systemd.services.electrs = {
      description = "Run electrs";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" "nginx.service"];
      after = [ "bitcoind.service" ];
      # create shell script to start up electrs safely with password parameter
      preStart = ''
        mkdir -m 0770 -p ${cfg.dataDir}
        chown 'electrs:electrs' ${cfg.dataDir}
        echo "${pkgs.electrs}/bin/electrs -vvv ${index-batch-size} ${jsonrpc-import} --timestamp --db-dir ${cfg.dataDir} --daemon-dir /var/lib/bitcoind --cookie=${config.services.bitcoind.rpcuser}:$(cat /secrets/bitcoin-rpcpassword) --electrum-rpc-addr=127.0.0.1:${toString cfg.port}" > /var/lib/electrs/startscript.sh
        chown -R 'electrs:electrs' ${cfg.dataDir}
        chmod u+x ${cfg.dataDir}/startscript.sh
        '';	
      serviceConfig = {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.dataDir}/startscript.sh";
        User = "electrs";
        Restart = "on-failure";
        RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening;
    };

    services.nginx = {
      enable = true;
      appendConfig = ''
        stream {
          upstream electrs {
            server 127.0.0.1:${toString config.services.electrs.port};
          }

          server {
            listen ${toString config.services.electrs.nginxport} ssl;
            proxy_pass electrs;

            ssl_certificate /secrets/ssl_certificate;
            ssl_certificate_key /secrets/ssl_certificate_key;
            ssl_session_cache shared:SSL:1m;
            ssl_session_timeout 4h;
            ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
            ssl_prefer_server_ciphers on;
          }
        }
      '';
    };
  };
}
