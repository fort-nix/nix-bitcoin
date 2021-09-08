{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-pool;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  lnd = config.services.lnd;

  network = config.services.bitcoind.network;
  rpclisten = "${cfg.rpcAddress}:${toString cfg.rpcPort}";
  configFile = builtins.toFile "pool.conf" ''
    rpclisten=${rpclisten}
    restlisten=${cfg.restAddress}:${toString cfg.restPort}
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}

    lnd.host=${lnd.rpcAddress}:${toString lnd.rpcPort}
    lnd.macaroondir=${lnd.networkDir}
    lnd.tlspath=${secretsDir}/lnd-cert

    ${cfg.extraConfig}
  '';
in {
  options.services.lightning-pool = {
    enable = mkEnableOption "lightning-pool";
    rpcAddress = mkOption {
       type = types.str;
       default = "localhost";
       description = "Address to listen for gRPC connections.";
    };
    rpcPort = mkOption {
       type = types.port;
       default = 12010;
       description = "Port to listen for gRPC connections.";
    };
    restAddress = mkOption {
       type = types.str;
       default = cfg.rpcAddress;
       description = "Address to listen for REST connections.";
    };
    restPort = mkOption {
       type = types.port;
       default = 8281;
       description = "Port to listen for REST connections.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.lightning-pool;
      description = "The package providing lightning-pool binaries.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lightning-pool";
      description = "The data directory for lightning-pool.";
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.nix-bitcoin.torClientAddressWithPort else null;
      description = "host:port of SOCKS5 proxy for connnecting to the pool auction server.";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        debuglevel=trace
      '';
      description = "Extra lines appended to the configuration file.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "pool" ''
        exec ${cfg.package}/bin/pool \
          --rpcserver ${rpclisten} \
          --network ${network} \
          --basedir '${cfg.dataDir}' "$@"
      '';
      description = "Binary to connect with the lightning-pool instance.";
    };
    enforceTor = nbLib.enforceTor;
  };

  config = mkIf cfg.enable {
    services.lnd.enable = true;

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 lnd lnd - -"
    ];

    systemd.services.lightning-pool = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      preStart = ''
        mkdir -p '${cfg.dataDir}/${network}'
        ln -sfn ${configFile} '${cfg.dataDir}/${network}/poold.conf'
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${cfg.package}/bin/poold --basedir='${cfg.dataDir}' --network=${network}";
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // (nbLib.allowedIPAddresses cfg.enforceTor)
        // nbLib.allowNetlink; # required by gRPC-Go
    };
  };
}
