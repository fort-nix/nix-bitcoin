{ config, lib, pkgs, ... }:

with lib;
let
  options.services.clightning-rest = {
    enable = mkEnableOption "lightning-rest";
    port = mkOption {
      type = types.port;
      default = 3001;
      description = mdDoc "REST server port.";
    };
    docPort = mkOption {
      type = types.port;
      default = 4001;
      description = mdDoc "Swagger API documentation server port.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/clightning-rest";
      description = mdDoc "The data directory for clightning-rest.";
    };
    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      example = {
        DOMAIN = "mynode.org";
      };
      description = mdDoc ''
        Extra config options.
        See: https://github.com/Ride-The-Lightning/c-lightning-REST#option-1-via-config-file-cl-rest-configjson
      '';
    };
    # Used by ./rtl.nix
    group = mkOption {
      readOnly = true;
      default = clightning.group;
      description = mdDoc "The group under which clightning-rest is run.";
    };
    # Rest server address.
    # Not configurable. The server always listens on all interfaces:
    # https://github.com/Ride-The-Lightning/c-lightning-REST/issues/84
    # Required by netns-isolation.
    address = mkOption {
      internal = true;
      default = "0.0.0.0";
    };
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.clightning-rest;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;

  inherit (config.services)
    bitcoind
    clightning;

  configFile = builtins.toFile "clightning-rest-config" (builtins.toJSON ({
    PORT = cfg.port;
    DOCPORT = cfg.docPort;
    LNRPCPATH = "${clightning.dataDir}/${bitcoind.makeNetworkName "bitcoin" "regtest"}/lightning-rpc";
    EXECMODE = "production";
    PROTOCOL = "https";
    RPCCOMMANDS = ["*"];
  } // cfg.extraConfig));
in {
  inherit options;

  config = mkIf cfg.enable {
    services.clightning.enable = true;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${clightning.user} ${cfg.group} - -"
    ];

    systemd.services.clightning-rest = mkIf cfg.enable {
      wantedBy = [ "multi-user.target" ];
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      path = [ pkgs.openssl ];
      environment.CL_REST_STATE_DIR = cfg.dataDir;
      preStart = ''
        ln -sfn ${configFile} cl-rest-config.json
      '';
      postStart = ''
        while [[ ! -e '${cfg.dataDir}/certs/access.macaroon' ]]; do
          sleep 0.1
        done
      '';
      serviceConfig = nbLib.defaultHardening // {
        # clightning-rest reads the config file from the working directory
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${nbPkgs.clightning-rest}/bin/cl-rest";
        # Show "clightning-rest" instead of "node" in the journal
        SyslogIdentifier = "clightning-rest";
        User = clightning.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = [ cfg.dataDir ];
        inherit (nbLib.allowNetlink) RestrictAddressFamilies;
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // nbLib.nodejs;
    };
  };
}
