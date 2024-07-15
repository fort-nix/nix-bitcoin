{ config, lib, pkgs, ... }:

with lib;
let
  options.services.fulcrum = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable fulcrum, an Electrum server implemented in C++.

        Compared to electrs, fulcrum has a 3x larger database size but
        can serve arbitrary address queries instantly.

        fulcrum also enables `txindex` in bitcoind (this is a requirement),
        which increases the bitcoind datadir size by 8% of the `blocks` size.

        This module disables peering (a distributed list of electrum servers that can
        be queried by clients), but you can manually enable it via option
        {option}`extraConfig`.
      '';
    };
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
      default = "/var/lib/fulcrum";
      description = "The data directory for fulcrum.";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        peering = true
      '';
      description = ''
        Extra lines appended to the configuration file.

        See all available options at
        https://github.com/cculianu/Fulcrum/blob/master/doc/fulcrum-example-config.conf
      '';
    };
    user = mkOption {
      type = types.str;
      default = "fulcrum";
      description = "The user as which to run fulcrum.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run fulcrum.";
    };
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.fulcrum;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;

  configFile = builtins.toFile "fulcrum.conf" ''
    datadir = ${cfg.dataDir}
    tcp = ${cfg.address}:${toString cfg.port}

    bitcoind = ${nbLib.addressWithPort bitcoind.rpc.address bitcoind.rpc.port}
    rpcuser = ${bitcoind.rpc.users.public.name}

    # Disable logging timestamps
    ts-format = none

    peering = false

    ${cfg.extraConfig}
  '';
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.prune == 0;
        message = "Fulcrum does not support bitcoind pruning.";
      }
      { assertion =
          !(config.services ? electrs)
          || !config.services.electrs.enable
          || config.services.electrs.port != cfg.port;
        message = ''
          Fulcrum and Electrs can't both bind to TCP RPC port ${cfg.port}.
          Change `services.electrs.port` or `services.fulcrum.port`
          to a port other than ${cfg.port}.
        '';
      }
    ];

    services.bitcoind = {
      enable = true;
      txindex = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.fulcrum = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      preStart = ''
        {
          cat ${configFile}
          echo "rpcpassword = $(cat ${secretsDir}/bitcoin-rpcpassword-public)"
        } > '${cfg.dataDir}/fulcrum.conf'
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${config.nix-bitcoin.pkgs.fulcrum}/bin/Fulcrum '${cfg.dataDir}/fulcrum.conf'";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
        ProcSubset = "all"; # Fulcrum requires read access to /proc/meminfo
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
