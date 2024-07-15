{ config, pkgs, lib, ... }:

with lib;
let
  options = {
    services.liquidd = {
      enable = mkEnableOption "Liquid Bitcoin sidechain daemon";
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen for peer connections.";
      };
      port = mkOption {
        type = types.port;
        default = 7042;
        description = "Override the default port on which to listen for connections.";
      };
      onionPort = mkOption {
        type = types.nullOr types.port;
        # When the liquidd onion service is enabled, add an onion-tagged socket
        # to distinguish local connections from Tor connections
        default = if (config.nix-bitcoin.onionServices.liquidd.enable or false) then 7043 else null;
        description = ''
          Port to listen for Tor peer connections.
          If set, inbound connections to this port are tagged as onion peers.
        '';
      };
      listen = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Listen for peer connections at `address:port`
          and `address:onionPort` (if {option}`onionPort` is set).
        '';
      };
      listenWhitelisted = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Listen for peer connections at `address:whitelistedPort`.
          Peers connected through this socket are automatically whitelisted.
        '';
      };
      whitelistedPort = mkOption {
        type = types.port;
        default = 7044;
        description = "See {option}`listenWhitelisted`.";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        example = ''
          par=16
          rpcthreads=16
          logips=1
        '';
        description = "Extra lines appended to {file}`elements.conf`.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/liquidd";
        description = "The data directory for liquidd.";
      };
      rpc = {
        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Address to listen for JSON-RPC connections.";
        };
        port = mkOption {
          type = types.port;
          default = 7041;
          description = "Port to listen for JSON-RPC connections.";
        };
        users = mkOption {
          default = {};
          example = {
            alice.passwordHMAC = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
            bob.passwordHMAC = "b2dd077cb54591a2f3139e69a897ac$4e71f08d48b4347cf8eff3815c0e25ae2e9a4340474079f55705f40574f4ec99";
          };
          type = with types; attrsOf (submodule rpcUserOpts);
          description = ''
            RPC user information for JSON-RPC connections.
          '';
        };
      };
      rpcallowip = mkOption {
        type = types.listOf types.str;
        default = [ "127.0.0.1" ];
        description = ''
          Allow JSON-RPC connections from specified source.
        '';
      };
      rpcuser = mkOption {
          type = types.str;
          default = "liquidrpc";
          description = "Username for JSON-RPC connections";
      };
      proxy = mkOption {
        type = types.nullOr types.str;
        default = if cfg.tor.proxy then config.nix-bitcoin.torClientAddressWithPort else null;
        description = "Connect through SOCKS5 proxy";
      };
      dbCache = mkOption {
        type = types.nullOr (types.ints.between 4 16384);
        default = null;
        example = 4000;
        description = "Override the default database cache size in megabytes.";
      };
      prune = mkOption {
        type = types.nullOr (types.coercedTo
          (types.enum [ "disable" "manual" ])
          (x: if x == "disable" then 0 else 1)
          types.ints.unsigned
        );
        default = null;
        example = 10000;
        description = ''
          Reduce storage requirements by enabling pruning (deleting) of old
          blocks. This allows the pruneblockchain RPC to be called to delete
          specific blocks, and enables automatic pruning of old blocks if a
          target size in MiB is provided. This mode is incompatible with -txindex
          and -rescan. Warning: Reverting this setting requires re-downloading
          the entire blockchain. (`disable` = disable pruning blocks, `manual`
          = allow manual pruning via RPC, >=550 = automatically prune block files
          to stay under the specified target size in MiB)
        '';
      };
      validatepegin = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Validate pegin claims. All functionaries must run this.
        '';
      };
      user = mkOption {
        type = types.str;
        default = "liquid";
        description = "The user as which to run liquidd.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run liquidd.";
      };
      cli = mkOption {
        readOnly = true;
        default = pkgs.writers.writeBashBin "elements-cli" ''
          ${nbPkgs.elementsd}/bin/elements-cli -datadir='${cfg.dataDir}' "$@"
        '';
        defaultText = "(See source)";
        description = "Binary to connect with the liquidd instance.";
      };
      swapCli = mkOption {
        default = pkgs.writers.writeBashBin "liquidswap-cli" ''
          ${nbPkgs.liquid-swap}/bin/liquidswap-cli -c '${cfg.dataDir}/elements.conf' "$@"
        '';
        defaultText = "(See source)";
        description = "Binary for managing liquid swaps.";
      };
      tor = nbLib.tor;
    };
  };

  cfg = config.services.liquidd;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  bitcoind = config.services.bitcoind;

  configFile = pkgs.writeText "elements.conf" ''
    # We're already logging via journald
    nodebuglogfile=1

    startupnotify=/run/current-system/systemd/bin/systemd-notify --ready

    chain=${bitcoind.makeNetworkName "liquidv1" ''
      regtest
      [regtest]'' # Add [regtest] config section
    }
    ${optionalString (cfg.dbCache != null) "dbcache=${toString cfg.dbCache}"}
    ${optionalString (cfg.prune != null) "prune=${toString cfg.prune}"}
    ${optionalString (cfg.validatepegin != null) "validatepegin=${if cfg.validatepegin then "1" else "0"}"}

    # Connection options
    listen=${if (cfg.listen || cfg.listenWhitelisted) then "1" else "0"}
    ${optionalString cfg.listen
      "bind=${cfg.address}:${toString cfg.port}"}
    ${optionalString (cfg.listen && cfg.onionPort != null)
      "bind=${cfg.address}:${toString cfg.onionPort}=onion"}
    ${optionalString cfg.listenWhitelisted
      "whitebind=${cfg.address}:${toString cfg.whitelistedPort}"}
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}

    # RPC server options
    rpcport=${toString cfg.rpc.port}
    ${concatMapStringsSep  "\n"
      (rpcUser: "rpcauth=${rpcUser.name}:${rpcUser.passwordHMAC}")
      (attrValues cfg.rpc.users)
    }
    rpcbind=${cfg.rpc.address}
    rpcconnect=${cfg.rpc.address}
    ${lib.concatMapStrings (rpcallowip: "rpcallowip=${rpcallowip}\n") cfg.rpcallowip}
    rpcuser=${cfg.rpcuser}
    mainchainrpchost=${nbLib.address bitcoind.rpc.address}
    mainchainrpcport=${toString bitcoind.rpc.port}
    mainchainrpcuser=${bitcoind.rpc.users.public.name}

    # Extra config options (from liquidd nixos service)
    ${cfg.extraConfig}
  '';
  rpcUserOpts = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        example = "alice";
        description = ''
          Username for JSON-RPC connections.
        '';
      };
      passwordHMAC = mkOption {
        type = with types; uniq (strMatching "[0-9a-f]+\\$[0-9a-f]{64}");
        example = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
        description = ''
          Password HMAC-SHA-256 for JSON-RPC connections. Must be a string of the
          format `<SALT-HEX>$<HMAC-HEX>`.
        '';
      };
    };
    config = {
      name = mkDefault name;
    };
  };
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.regtest -> cfg.validatepegin != true;
        message = "liquidd: `validatepegin` is incompatible with regtest.";
      }
    ];

    services.bitcoind.enable = true;

    environment.systemPackages = [
      nbPkgs.elementsd
      (hiPrio cfg.cli)
      (hiPrio cfg.swapCli)
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.liquidd = {
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        install -m 640 ${configFile} '${cfg.dataDir}/elements.conf'
        {
          echo "rpcpassword=$(cat ${secretsDir}/liquid-rpcpassword)"
          echo "mainchainrpcpassword=$(cat ${secretsDir}/bitcoin-rpcpassword-public)"
        } >> '${cfg.dataDir}/elements.conf'
      '';
      serviceConfig = nbLib.defaultHardening // {
        Type = "notify";
        NotifyAccess = "all";
        User = cfg.user;
        Group = cfg.group;
        TimeoutStartSec = "2h";
        TimeoutStopSec = "2h";
        ExecStart = "${nbPkgs.elementsd}/bin/elementsd -datadir='${cfg.dataDir}'";
        Restart = "on-failure";
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

    nix-bitcoin.secrets.liquid-rpcpassword.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.liquid = ''
      makePasswordSecret liquid-rpcpassword
    '';
  };
}
