{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-loop;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
in {

  options.services.lightning-loop = {
    enable = mkEnableOption "lightning-loop";
    package = mkOption {
      type = types.package;
      default = pkgs.nix-bitcoin.lightning-loop;
      defaultText = "pkgs.nix-bitcoin.lightning-loop";
      description = "The package providing lightning-loop binaries.";
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Connect through SOCKS5 proxy";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to loopd.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "loop"
      # Switch user because lnd makes datadir contents readable by user only
      ''
        exec sudo -u lnd ${cfg.package}/bin/loop "$@"
      '';
      description = "Binary to connect with the lnd instance.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = config.services.lnd.enable;
        message = "lightning-loop requires lnd.";
      }
    ];

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.services.lightning-loop = {
      description = "Run loopd";
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = ''
          ${cfg.package}/bin/loopd \
          --lnd.host=${config.services.lnd.listen}:10009 \
          --lnd.macaroondir=${config.services.lnd.dataDir}/chain/bitcoin/mainnet \
          --lnd.tlspath=${secretsDir}/lnd-cert \
          ${optionalString (cfg.proxy != null) "--server.proxy=${cfg.proxy}"} \
          ${cfg.extraArgs}
        '';
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${config.services.lnd.dataDir}";
      } // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP);
    };
  };
}
