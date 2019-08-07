{ config, lib, pkgs, ... }:

with lib;

let
  nix-bitcoin-services = pkgs.callPackage ./nix-bitcoin-services.nix { };
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
    user = mkOption {
      type = types.str;
      default = "electrs";
      description = "The user as which to run electrs.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run electrs.";
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
        description = "RPC port.";
    };
    onionport = mkOption {
        type = types.ints.u16;
        default = 50002;
        description = "Port on which to listen for tor client connections.";
    };
    nginxport = mkOption {
        type = types.ints.u16;
        default = 50003;
        description = "Port on which to listen for TLS client connections.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
        name = cfg.user;
        description = "electrs User";
        group = cfg.group;
        extraGroups = [ "bitcoinrpc" "keys" "bitcoin"];
        home = cfg.dataDir;
    };
    users.groups.electrs = {
      name = cfg.group;
    };   

    systemd.services.electrs = {
      description = "Run electrs";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" "nginx.service"];
      after = [ "bitcoind.service" ];
      # create shell script to start up electrs safely with password parameter
      preStart = ''
        mkdir -m 0770 -p ${cfg.dataDir}
        chown -R '${cfg.user}:${cfg.group}' ${cfg.dataDir}
        echo "${pkgs.electrs}/bin/electrs -vvv ${index-batch-size} ${jsonrpc-import} --timestamp --db-dir ${cfg.dataDir} --daemon-dir /var/lib/bitcoind --cookie=${config.services.bitcoind.rpcuser}:$(cat /secrets/bitcoin-rpcpassword) --electrum-rpc-addr=127.0.0.1:${toString cfg.port}" > /run/electrs/startscript.sh
        '';	
      serviceConfig = rec {
        RuntimeDirectory = "electrs";
        RuntimeDirectoryMode = "700";
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.bash}/bin/bash /run/${RuntimeDirectory}/startscript.sh";
        User = "electrs";
        Restart = "on-failure";
        RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening
        // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP
        );
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
