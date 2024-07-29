{ config, lib, pkgs, ... }:

with lib;
let
  options.services.joinmarket-ob-watcher = {
    enable = mkEnableOption "JoinMarket orderbook watcher";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 62601;
      description = "HTTP server port.";
    };
    dataDir = mkOption {
      readOnly = true;
      default = "/var/lib/joinmarket-ob-watcher";
      description = "The data directory for JoinMarket orderbook watcher.";
    };
    settings = mkOption {
      type = with types; attrsOf anything;
      example = {
        LOGGING = {
          console_log_level = "DEBUG";
        };
      };
      description = ''
        Joinmarket settings.
        See here for possible options:
        https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/v0.9.11/src/jmclient/configure.py#L98
      '';
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket-ob-watcher";
      description = "The user as which to run JoinMarket.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run JoinMarket.";
    };
    # This option is only used by netns-isolation.
    # Tor is always enabled.
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.joinmarket-ob-watcher;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  inherit (config.services) bitcoind joinmarket;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind.rpc.users.joinmarket-ob-watcher = {
      passwordHMACFromFile = true;
      rpcwhitelist = bitcoind.rpc.users.public.rpcwhitelist ++ [
        "listwallets"
      ];
    };

    # Joinmarket is Tor-only
    services.tor = {
      enable = true;
      client.enable = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    services.joinmarket-ob-watcher.settings = {
      BLOCKCHAIN = config.services.joinmarket.settings.BLOCKCHAIN // {
        rpc_user = bitcoind.rpc.users.joinmarket-ob-watcher.name;
        rpc_wallet_file = "";
      };
      inherit (config.services.joinmarket.settings)
        "MESSAGING:onion"
        "MESSAGING:server1"
        "MESSAGING:server2"
        "MESSAGING:server3";
    };

    systemd.services.joinmarket-ob-watcher = rec {
      wantedBy = [ "multi-user.target" ];
      requires = [ "tor.service" "bitcoind.service" ];
      after = requires ++ [ "nix-bitcoin-secrets.target" ];
      # The service writes to HOME/.config/matplotlib
      environment.HOME = cfg.dataDir;
      preStart = ''
        {
          cat ${builtins.toFile "joinmarket-ob-watcher.cfg" ((generators.toINI {}) cfg.settings)}
          echo
          echo '[BLOCKCHAIN]'
          echo "rpc_password = $(cat ${secretsDir}/bitcoin-rpcpassword-joinmarket-ob-watcher)"
        } > '${cfg.dataDir}/joinmarket.cfg'
      '';
      serviceConfig = nbLib.defaultHardening // rec {
        StateDirectory = "joinmarket-ob-watcher";
        StateDirectoryMode = "770";
        WorkingDirectory = cfg.dataDir; # The service creates dir 'logs' in the working dir
        User = cfg.user;
        ExecStart = ''
          ${nbPkgs.joinmarket}/bin/jm-ob-watcher --datadir=${cfg.dataDir} \
            --host=${cfg.address} --port=${toString cfg.port}
        '';
        SystemCallFilter = nbLib.defaultHardening.SystemCallFilter ++ [ "mbind" ] ;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets = {
      bitcoin-rpcpassword-joinmarket-ob-watcher.user = cfg.user;
      bitcoin-HMAC-joinmarket-ob-watcher.user = bitcoind.user;
    };
    nix-bitcoin.generateSecretsCmds.joinmarket-ob-watcher = ''
      makeBitcoinRPCPassword joinmarket-ob-watcher
    '';
  };
}
