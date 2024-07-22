{ config, lib, pkgs, ... }:

with lib;
let
  options.services.electrs = {
    enable = mkEnableOption "electrs, an Electrum server implemented in Rust";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for RPC connections.";
    };
    port = mkOption {
      type = types.port;
      default = 50001;
      description = "Port to listen for RPC connections.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/electrs";
      description = "The data directory for electrs.";
    };
    monitoringPort = mkOption {
      type = types.port;
      default = 4224;
      description = "Prometheus monitoring port.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to electrs.";
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
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.electrs;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.prune == 0;
        message = "electrs does not support bitcoind pruning.";
      }
    ];

    services.bitcoind = {
      enable = true;
      listenWhitelisted = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.electrs = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      preStart = ''
        echo "auth = \"${bitcoind.rpc.users.public.name}:$(cat ${secretsDir}/bitcoin-rpcpassword-public)\"" \
          > electrs.toml
        '';
      serviceConfig = nbLib.defaultHardening // {
        # electrs only uses the working directory for reading electrs.toml
        WorkingDirectory = cfg.dataDir;
        ExecStart = ''
          ${config.nix-bitcoin.pkgs.electrs}/bin/electrs \
          --log-filters=INFO \
          --network=${bitcoind.makeNetworkName "bitcoin" "regtest"} \
          --db-dir='${cfg.dataDir}' \
          --daemon-dir='${bitcoind.dataDir}' \
          --electrum-rpc-addr=${cfg.address}:${toString cfg.port} \
          --monitoring-addr=${cfg.address}:${toString cfg.monitoringPort} \
          --daemon-rpc-addr=${nbLib.addressWithPort bitcoind.rpc.address bitcoind.rpc.port} \
          --daemon-p2p-addr=${nbLib.addressWithPort bitcoind.address bitcoind.whitelistedPort} \
          ${cfg.extraArgs}
        '';
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}
