{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.spark-wallet;
  dataDir = "/var/lib/spark-wallet/";
  onion-chef-service = (if cfg.onion-service then [ "onion-chef.service" ] else []);
  run-spark-wallet = pkgs.writeScript "run-spark-wallet" ''
    CMD="${pkgs.spark-wallet}/bin/spark-wallet --ln-path ${cfg.ln-path} -Q -k -c /secrets/spark-wallet-login"
    ${optionalString cfg.onion-service
      ''
      echo Getting onion hostname
      CMD="$CMD --public-url http://$(cat /var/lib/onion-chef/clightning/spark-wallet)"
      ''
    }
    echo Running $CMD
    $CMD
  '';
in {
  options.services.spark-wallet = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the spark-wallet service will be installed.
      '';
    };
    ln-path = mkOption {
      type = types.path;
      default = "/var/lib/clightning";
      description = ''
        "The path of the clightning data directory.";
      '';
    };
    onion-service = mkOption {
      type = types.bool;
      default = false;
      description = ''
        "If enabled, configures spark-wallet to be reachable through an onion service.";
      '';
    };
  };

  config = mkIf cfg.enable {
    services.tor.enable = cfg.onion-service;
    services.tor.hiddenServices.spark-wallet = mkIf cfg.onion-service {
      map = [{
        port = 80; toPort = 9737;
      }];
      version = 3;
    };
    services.onion-chef.enable = cfg.onion-service;
    services.onion-chef.access.clightning = if cfg.onion-service then [ "spark-wallet" ] else [];
    systemd.services.spark-wallet = {
      description = "Run spark-wallet";
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ] ++ onion-chef-service;
      after = [ "clightning.service" ]  ++ onion-chef-service;
      serviceConfig = {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.bash}/bin/bash ${run-spark-wallet}";
        User = "clightning";
        Restart = "on-failure";
        RestartSec = "10s";
        PrivateTmp = "true";
        ProtectSystem = "full";
        NoNewPrivileges = "true";
        PrivateDevices = "true";
      };
    };
  };
}
