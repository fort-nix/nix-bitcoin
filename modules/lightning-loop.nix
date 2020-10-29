{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-loop;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
  network = config.services.bitcoind.network;
  configFile = builtins.toFile "loop.conf" ''
    datadir=${cfg.dataDir}
    network=${network}
    logdir=${cfg.dataDir}/logs
    tlscertpath=${secretsDir}/loop-cert
    tlskeypath=${secretsDir}/loop-key

    lnd.host=${builtins.elemAt config.services.lnd.rpclisten 0}:${toString config.services.lnd.rpcPort}
    lnd.macaroondir=${config.services.lnd.networkDir}
    lnd.tlspath=${secretsDir}/lnd-cert

    ${optionalString (cfg.proxy != null) "server.proxy=${cfg.proxy}"}

    ${cfg.extraConfig}
  '';
in {
  options.services.lightning-loop = {
    enable = mkEnableOption "lightning-loop";
    package = mkOption {
      type = types.package;
      default = pkgs.nix-bitcoin.lightning-loop;
      defaultText = "pkgs.nix-bitcoin.lightning-loop";
      description = "The package providing lightning-loop binaries.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lightning-loop";
      description = "The data directory for lightning-loop.";
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.services.tor.client.socksListenAddress else null;
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
        ${cfg.cliExec} ${cfg.package}/bin/loop \
        --macaroonpath '${cfg.dataDir}/${network}/loop.macaroon' \
        --tlscertpath '${secretsDir}/loop-cert' "$@"
      '';
      description = "Binary to connect with the lightning-loop instance.";
    };
    inherit (nix-bitcoin-services) cliExec;
    enforceTor = nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    services.lnd.enable = true;

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 lnd lnd - -"
    ];

    systemd.services.lightning-loop = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = "${cfg.package}/bin/loopd --configfile=${configFile}";
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
      } // (if cfg.enforceTor
            then nix-bitcoin-services.allowTor
            else nix-bitcoin-services.allowAnyIP);
    };

     nix-bitcoin.secrets = {
       loop-key.user = "lnd";
       loop-cert.user = "lnd";
     };
  };
}
