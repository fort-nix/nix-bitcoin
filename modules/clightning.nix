{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.clightning;
  home = "/var/lib/clightning";
  configFile = pkgs.writeText "config" ''
    autolisten=false
    network=bitcoin
    bitcoin-rpcuser=${cfg.bitcoin-rpcuser}
    bitcoin-rpcpassword=${cfg.bitcoin-rpcpassword}
  '';
in {
  options.services.clightning = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the clightning service will be installed.
      '';
    };
    autolisten = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the clightning service will listen.
      '';
    };
    bitcoin-rpcuser = mkOption {
      type = types.string;
      description = ''
        Bitcoin RPC user
      '';
    };
    bitcoin-rpcpassword = mkOption {
      type = types.string;
      description = ''
        Bitcoin RPC password
      '';
    };
  };

  config = mkIf cfg.enable {
      users.users.clightning =
        {
          description = "clightning User";
          createHome  = true;
          inherit home;
      };
      systemd.services.clightning =
        { description = "Run clightningd";
          path  = [ pkgs.clightning pkgs.bitcoin ];
          wantedBy = [ "multi-user.target" ];
          preStart = ''
            mkdir -p ${home}/.lightning
            ln -sf ${configFile} ${home}/.lightning/config
            '';
          serviceConfig =
            {
              ExecStart = "${pkgs.clightning}/bin/lightningd";
              User = "clightning";
              Restart = "on-failure";
              PrivateTmp = "true";
              ProtectSystem = "full";
              NoNewPrivileges = "true";
              PrivateDevices = "true";
              MemoryDenyWriteExecute = "true";
            };
        };
    };
}
