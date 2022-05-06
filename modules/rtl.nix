{ config, lib, pkgs, ... }:

with lib;
let
  options.services.rtl = {
    enable = mkEnableOption "Ride The Lightning, a web interface for lnd and clightning ";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 3000;
      description = "HTTP server port.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/rtl";
      description = "The data directory for RTL.";
    };
    nodes = {
      clightning = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the clightning node interface.";
      };
      lnd = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the lnd node interface.";
      };
      reverseOrder = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Reverse the order of nodes shown in the UI.
          By default, clightning is shown before lnd.
        '';
      };
    };
    loop = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable swaps with lightning-loop.";
    };
    nightTheme = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the Night UI Theme.";
    };
    extraCurrency = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "USD";
      description = ''
        Currency code (ISO 4217) of the extra currency used for displaying balances.
        When set, this option enables online currency rate fetching.
        Warning: Rate fetching requires outgoing clearnet connections, so option
        `tor.enforce` is automatically disabled.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "rtl";
      description = "The user as which to run RTL.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run RTL.";
    };
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.rtl;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  node = { isLnd, index }: ''
    {
      "index": ${toString index},
      "lnNode": "Node",
      "lnImplementation": "${if isLnd then "LND" else "CLT"}",
      "Authentication": {
        ${optionalString (isLnd && cfg.loop)
          ''"swapMacaroonPath": "${lightning-loop.dataDir}/${bitcoind.network}",''
         }
        "macaroonPath": "${if isLnd
                           then "${cfg.dataDir}/macaroons"
                           else "${clightning-rest.dataDir}/certs"
                          }"
      },
      "Settings": {
        "userPersona": "OPERATOR",
        "themeMode": "${if cfg.nightTheme then "NIGHT" else "DAY"}",
        "themeColor": "PURPLE",
        ${optionalString isLnd
          ''"channelBackupPath": "${cfg.dataDir}/backup/lnd",''
         }
        "logLevel": "INFO",
        "fiatConversion": ${if cfg.extraCurrency == null then "false" else "true"},
        ${optionalString (cfg.extraCurrency != null)
          ''"currencyUnit": "${cfg.extraCurrency}",''
         }
        ${optionalString (isLnd && cfg.loop)
          ''"swapServerUrl": "https://${nbLib.addressWithPort lightning-loop.restAddress lightning-loop.restPort}",''
         }
        "lnServerUrl": "https://${
          if isLnd
          then nbLib.addressWithPort lnd.restAddress lnd.restPort
          else nbLib.addressWithPort clightning-rest.address clightning-rest.port
        }"
      }
    }
  '';

  nodes' = optional cfg.nodes.clightning (node { isLnd = false; index = 1; }) ++
           optional cfg.nodes.lnd        (node { isLnd = true;  index = 2; });

  nodes = if cfg.nodes.reverseOrder then reverseList nodes' else nodes';

  configFile = builtins.toFile "config" ''
    {
      "multiPass": "@multiPass@",
      "host": "${cfg.address}",
      "port": "${toString cfg.port}",
      "SSO": {
        "rtlSSO": 0
      },
      "nodes": [
        ${builtins.concatStringsSep ",\n" nodes}
      ]
    }
  '';

  inherit (config.services)
    bitcoind
    lnd
    clightning-rest
    lightning-loop;
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = cfg.nodes.clightning || cfg.nodes.lnd;
        message = ''
          RTL: At least one of `nodes.lnd` or `nodes.clightning` must be `true`.
        '';
      }
    ];

    services.lnd.enable = mkIf cfg.nodes.lnd true;
    services.lightning-loop.enable = mkIf cfg.loop true;
    services.clightning-rest.enable = mkIf cfg.nodes.clightning true;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    services.rtl.tor.enforce = mkIf (cfg.extraCurrency != null) false;

    systemd.services.rtl = rec {
      wantedBy = [ "multi-user.target" ];
      requires = optional cfg.nodes.clightning "clightning-rest.service" ++
                 optional cfg.nodes.lnd "lnd.service";
      after = requires;
      environment.RTL_CONFIG_PATH = cfg.dataDir;
      serviceConfig = nbLib.defaultHardening // {
        ExecStartPre = [
          (nbLib.script "rtl-setup-config" ''
            <${configFile} sed "s|@multiPass@|$(cat ${secretsDir}/rtl-password)|" \
              > '${cfg.dataDir}/RTL-Config.json'
          '')
        ] ++ optional cfg.nodes.lnd
          (nbLib.rootScript "rtl-copy-macaroon" ''
            install -D -o ${cfg.user} -g ${cfg.group} ${lnd.networkDir}/admin.macaroon \
              '${cfg.dataDir}/macaroons/admin.macaroon'
          '');
        ExecStart = "${nbPkgs.rtl}/bin/rtl";
        # Show "rtl" instead of "node" in the journal
        SyslogIdentifier = "rtl";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // nbLib.nodejs;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups =
        # Reads cert and macaroon from the clightning-rest datadir
        optional cfg.nodes.clightning clightning-rest.group ++
        optional cfg.loop lnd.group;
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets.rtl-password.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.rtl = ''
      makePasswordSecret rtl-password
    '';
  };
}
