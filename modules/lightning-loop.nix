{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-loop;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  lnd = config.services.lnd;

  network = config.services.bitcoind.network;
  rpclisten = "${cfg.rpcAddress}:${toString cfg.rpcPort}";
  configFile = builtins.toFile "loop.conf" ''
    datadir=${cfg.dataDir}
    network=${network}
    rpclisten=${rpclisten}
    restlisten=${cfg.restAddress}:${toString cfg.restPort}
    logdir=${cfg.dataDir}/logs
    tlscertpath=${secretsDir}/loop-cert
    tlskeypath=${secretsDir}/loop-key

    lnd.host=${lnd.rpcAddress}:${toString lnd.rpcPort}
    lnd.macaroonpath=${lnd.networkDir}/admin.macaroon
    lnd.tlspath=${secretsDir}/lnd-cert

    ${optionalString (cfg.proxy != null) "server.proxy=${cfg.proxy}"}

    ${cfg.extraConfig}
  '';
in {
  options.services.lightning-loop = {
    enable = mkEnableOption "lightning-loop";
    rpcAddress = mkOption {
       type = types.str;
       default = "localhost";
       description = "Address to listen for gRPC connections.";
    };
    rpcPort = mkOption {
       type = types.port;
       default = 11010;
       description = "Port to listen for gRPC connections.";
    };
    restAddress = mkOption {
       type = types.str;
       default = cfg.rpcAddress;
       description = "Address to listen for REST connections.";
    };
    restPort = mkOption {
       type = types.port;
       default = 8081;
       description = "Port to listen for REST connections.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.lightning-loop;
      description = "The package providing lightning-loop binaries.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lightning-loop";
      description = "The data directory for lightning-loop.";
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.nix-bitcoin.torClientAddressWithPort else null;
      description = "host:port of SOCKS5 proxy for connnecting to the loop server.";
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
      default = pkgs.writeScriptBin "loop" ''
        ${cfg.package}/bin/loop \
        --rpcserver ${rpclisten} \
        --macaroonpath '${cfg.dataDir}/${network}/loop.macaroon' \
        --tlscertpath '${secretsDir}/loop-cert' "$@"
      '';
      description = "Binary to connect with the lightning-loop instance.";
    };
    enforceTor = nbLib.enforceTor;
  };

  config = mkIf cfg.enable {
    services.lnd.enable = true;

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${lnd.user} ${lnd.group} - -"
    ];

    systemd.services.lightning-loop = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${cfg.package}/bin/loopd --configfile=${configFile}";
        User = lnd.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowedIPAddresses cfg.enforceTor;
    };

     nix-bitcoin.secrets = {
       loop-key.user = lnd.user;
       loop-cert.user = lnd.user;
     };
  };
}
