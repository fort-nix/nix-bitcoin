{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.spark-wallet;
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
  };

  config = mkIf cfg.enable {
    systemd.services.spark-wallet = {
      description = "Run spark-wallet";
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.spark-wallet.package}/bin/spark-wallet --ln-path ${cfg.ln-path} -k -c /secrets/spark-wallet-password";
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
