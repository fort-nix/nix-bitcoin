{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.faraday;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
  network = config.services.bitcoind.network;
  rpclisten = "${cfg.rpcAddress}:${toString cfg.rpcPort}";
in {

  options.services.faraday = {
    enable = mkEnableOption "faraday";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.faraday;
      defaultText = "pkgs.nix-bitcoin.faraday";
      description = "The package providing faraday binaries.";
    };
    rpcAddress = mkOption {
       type = types.str;
       default = "localhost";
       description = "Address to listen for gRPC connections.";
    };
    rpcPort = mkOption {
       type = types.port;
       default = 8465;
       description = "Port to listen for gRPC connections.";
    };
    faradayDir = mkOption {
      type = types.path;
      default = "/var/lib/faraday";
      description = "The data directory for faraday.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to faraday.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "frcli"
      ''
        ${cfg.package}/bin/frcli \
        --rpcserver ${rpclisten} \
        --faradaydir ${cfg.faradayDir} "$@"
      '';
      description = "Binary to connect with the faraday instance.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    services.lnd.enable = true;

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.faradayDir}' 0770 lnd lnd - -"
    ];


    systemd.services.faraday = {
      description = "Run faraday";
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        preStart = ''
        mkdir -p ${cfg.faradayDir}
        chown -R 'lnd:lnd' '${cfg.faradayDir}'
        '';
        ExecStart = ''
          ${cfg.package}/bin/faraday \
          --faradaydir=${cfg.faradayDir} \
          --rpclisten=${rpclisten} \
          --lnd.rpcserver=${config.services.lnd.rpcAddress}:${toString config.services.lnd.rpcPort} \
          --lnd.macaroondir=${config.services.lnd.networkDir} \
          --lnd.tlscertpath=${secretsDir}/lnd-cert 
        '';
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.faradayDir}";
      } // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP);
    };
  };
}
