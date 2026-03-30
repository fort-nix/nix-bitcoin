{ config, lib, pkgs, ... }:

with lib;
let
  options.services.utxoracle = {
    enable = mkEnableOption "UTXOracle, a Bitcoin price oracle using only on-chain data";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/utxoracle";
      description = "Directory for storing generated price charts.";
    };
    interval = mkOption {
      type = types.str;
      default = "daily";
      description = ''
        Systemd calendar expression for how often to run UTXOracle.
        See {manpage}`systemd.time(7)` for the format.
        Set to "daily" by default to generate yesterday's price once per day.
      '';
    };
    date = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "2025/01/15";
      description = ''
        Specific UTC date to evaluate in YYYY/MM/DD format.
        When null (default), evaluates yesterday's date.
      '';
    };
    recentBlocks = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Use the last 144 blocks instead of date mode.
        When enabled, the {option}`date` option is ignored.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "utxoracle";
      description = "The user as which to run UTXOracle.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run UTXOracle.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.utxoracle or (pkgs.callPackage ../pkgs/utxoracle {});
      description = "The UTXOracle package to use.";
    };
    cli = mkOption {
      readOnly = true;
      default = pkgs.writers.writeBashBin "utxoracle" ''
        ${cfg.package}/bin/utxoracle -p '${bitcoind.dataDir}' "$@"
      '';
      defaultText = literalExpression "(utxoracle cli wrapper)";
      description = "Binary for running UTXOracle with the correct data directory.";
    };
  };

  cfg = config.services.utxoracle;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.prune == 0;
        message = "UTXOracle requires an unpruned bitcoind node.";
      }
    ];

    services.bitcoind.enable = true;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.utxoracle = {
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      serviceConfig = nbLib.defaultHardening // {
        WorkingDirectory = cfg.dataDir;
        ExecStart = toString ([
          "${cfg.package}/bin/utxoracle"
          "-p" "${bitcoind.dataDir}"
        ] ++ optionals cfg.recentBlocks [
          "-rb"
        ] ++ optionals (cfg.date != null && !cfg.recentBlocks) [
          "-d" cfg.date
        ]);
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ReadWritePaths = [ cfg.dataDir ];
        ReadOnlyPaths = [ bitcoind.dataDir ];
        # UTXOracle tries to open a browser; ignore that failure
        SuccessExitStatus = [ 0 1 ];
      } // nbLib.allowLocalIPAddresses;
    };

    systemd.timers.utxoracle = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    environment.systemPackages = [ cfg.cli ];

    nix-bitcoin.operator.groups = [ cfg.group ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}
