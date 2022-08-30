{ config, lib, pkgs, ... }:

with lib;
let
  options.services.teos = {
    enable = mkEnableOption "Lightning watchtower compliant with BOLT13, written in Rust";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = mdDoc "Address to listen for RPC connections.";
    };
    port = mkOption {
      type = types.port;
      default = 8814;
      description = mdDoc "Port to listen for RPC connections.";
    };
    api = {
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = mdDoc "Address to listen for API connections.";
      };
      port = mkOption {
        type = types.port;
        default = 9814;
        description = mdDoc "Port to listen for API connections.";
      };
    };
    internalApi = {
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = mdDoc "Address to listen for internal API connections.";
      };
      port = mkOption {
        type = types.port;
        default = 50051;
        description = mdDoc "Port to listen for internal API connections.";
      };
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/teos";
      description = mdDoc "The data directory for teos.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = mdDoc "Extra command line arguments passed to teosd.";
    };
    user = mkOption {
      type = types.str;
      default = "teos";
      description = mdDoc "The user as which to run teos.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = mdDoc "The group as which to run teos.";
    };
    package = mkOption {
      type = types.package;
      default = nbPkgs.teos;
      defaultText = "config.nix-bitcoin.pkgs.teos";
      description = mdDoc "The package providing teos binaries.";
    };
    cli = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "teos-cli" ''
        ${cfg.package}/bin/teos-cli --datadir='${cfg.dataDir}' "$@"
      '';
      defaultText = "(See source)";
      description = mdDoc "Binary to connect with the teos instance.";
    };
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.teos;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind = {
      enable = true;
      listenWhitelisted = true;
    };

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.teos = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];

      # Example configuration file:
      # Ref.: https://github.com/talaia-labs/rust-teos/blob/master/teos/src/conf_template.toml
      preStart = ''
        install -m 640 /dev/null teos.toml

        cat <<EOF > teos.toml
        # API
        api_bind = "${cfg.api.address}"
        api_port = ${toString cfg.api.port}

        tor_control_port = 9051
        onion_hidden_service_port = 2121
        tor_support = false

        # RPC
        rpc_bind = "${cfg.address}"
        rpc_port = ${toString cfg.port}

        # bitcoind
        btc_network = "${bitcoind.makeNetworkName "bitcoin" "regtest"}"
        btc_rpc_user = "${bitcoind.rpc.users.public.name}"
        btc_rpc_password = "$(cat ${secretsDir}/bitcoin-rpcpassword-public)"
        btc_rpc_connect = "${bitcoind.rpc.address}"
        btc_rpc_port = ${toString bitcoind.rpc.port}

        # Flags
        debug = false
        overwrite_key = false

        # General
        subscription_slots = 10000
        subscription_duration = 4320
        expiry_delta = 6
        min_to_self_delay = 20
        polling_delta = 60

        # Internal API
        internal_api_bind = "${cfg.internalApi.address}"
        internal_api_port = ${toString cfg.internalApi.port}
        EOF
      '';

      serviceConfig = nbLib.defaultHardening // {
        WorkingDirectory = cfg.dataDir;
        ExecStart = ''
          ${cfg.package}/bin/teosd \
          --datadir='${cfg.dataDir}' \
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
    nix-bitcoin.operator.groups = [ cfg.group ];
  };
}
