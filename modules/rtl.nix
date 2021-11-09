{ config, lib, pkgs, ... }:

with lib;
let
  options.services.rtl = {
    enable = mkEnableOption "rtl";
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
        description = "Add a node interface for clightning.";
      };
      lnd = mkOption {
        type = types.bool;
        default = false;
        description = "Add a node interface for lnd.";
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
    cl-rest = {
      enable = mkOption {
        type = types.bool;
        default = cfg.nodes.clightning;
        description = "Enable c-lightning-REST server.";
      };
      address = mkOption {
        readOnly = true;
        default = "0.0.0.0";
        description = ''
          Rest server address.
          Not configurable. The server always listens on all interfaces:
          https://github.com/Ride-The-Lightning/c-lightning-REST/issues/84
        '';
      };
      port = mkOption {
        type = types.port;
        default = 3001;
        description = "REST server port.";
      };
      docPort = mkOption {
        type = types.port;
        default = 4001;
        description = "Swagger API documentation server port.";
      };
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
    inherit (nbLib) enforceTor;
  };

  cfg = config.services.rtl;
  nbLib = config.nix-bitcoin.lib;
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
                           else "${cl-rest.dataDir}/certs"
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
        "fiatConversion": false,
        ${optionalString (isLnd && cfg.loop)
          ''"swapServerUrl": "https://${nbLib.addressWithPort lightning-loop.restAddress lightning-loop.restPort}",''
         }
        "lnServerUrl": "https://${
          if isLnd
          then nbLib.addressWithPort lnd.restAddress lnd.restPort
          else nbLib.addressWithPort cfg.cl-rest.address cfg.cl-rest.port
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

  cl-rest = {
    configFile = builtins.toFile "config" ''
      {
	      "PORT": ${toString cfg.cl-rest.port},
        "DOCPORT": ${toString cfg.cl-rest.docPort},
        "LNRPCPATH": "${clightning.dataDir}/${bitcoind.makeNetworkName "bitcoin" "regtest"}/lightning-rpc",
	      "PROTOCOL": "https",
	      "EXECMODE": "production",
	      "RPCCOMMANDS": ["*"]
      }
    '';
    # serviceConfig.StateDirectory
    dataDir = "/var/lib/cl-rest";
  };

  inherit (config.services)
    bitcoind
    lnd
    clightning
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
    services.clightning.enable = mkIf cfg.nodes.clightning true;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.rtl = rec {
      wantedBy = [ "multi-user.target" ];
      requires = optional cfg.nodes.clightning "cl-rest.service" ++
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
        ExecStart = "${pkgs.nodejs}/bin/node ${config.nix-bitcoin.pkgs.rtl}/lib/node_modules/rtl/rtl";
        # Show "rtl" instead of "node" in the journal
        SyslogIdentifier = "rtl";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowedIPAddresses cfg.enforceTor
        // nbLib.nodejs;
    };

    systemd.services.cl-rest = mkIf cfg.cl-rest.enable {
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      path = [ pkgs.openssl ];
      preStart = ''
        ln -sfn ${cl-rest.configFile} cl-rest-config.json
      '';
      environment.CL_REST_STATE_DIR = cl-rest.dataDir;
      serviceConfig = nbLib.defaultHardening // {
        StateDirectory = "cl-rest";
        # cl-rest reads the config file from the working directory
        WorkingDirectory = cl-rest.dataDir;
        ExecStart = "${pkgs.nodejs}/bin/node ${config.nix-bitcoin.pkgs.cl-rest}/lib/node_modules/c-lightning-rest/cl-rest";
        # Show "cl-rest" instead of "node" in the journal
        SyslogIdentifier = "cl-rest";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowLocalIPAddresses
        // nbLib.nodejs;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups =
        # Enable clightning RPC access for cl-rest
        optional cfg.cl-rest.enable clightning.group ++
        optional cfg.loop lnd.group;
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets.rtl-password.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.rtl = ''
      makePasswordSecret rtl-password
    '';
  };
}
