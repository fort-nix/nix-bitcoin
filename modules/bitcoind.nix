{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.bitcoind;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;

  configFile = pkgs.writeText "bitcoin.conf" ''
    # We're already logging via journald
    nodebuglogfile=1

    startupnotify=/run/current-system/systemd/bin/systemd-notify --ready

    ${optionalString cfg.regtest ''
      regtest=1
      [regtest]
    ''}
    ${optionalString (cfg.dbCache != null) "dbcache=${toString cfg.dbCache}"}
    prune=${toString cfg.prune}
    ${optionalString (cfg.sysperms != null) "sysperms=${if cfg.sysperms then "1" else "0"}"}
    ${optionalString (cfg.disablewallet != null) "disablewallet=${if cfg.disablewallet then "1" else "0"}"}
    ${optionalString (cfg.assumevalid != null) "assumevalid=${cfg.assumevalid}"}

    # Connection options
    ${optionalString cfg.listen "bind=${cfg.address}${optionalString cfg.enforceTor "=onion"}"}
    port=${toString cfg.port}
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}
    listen=${if cfg.listen then "1" else "0"}
    ${optionalString (cfg.discover != null) "discover=${if cfg.discover then "1" else "0"}"}
    ${lib.concatMapStrings (node: "addnode=${node}\n") cfg.addnodes}

    # RPC server options
    rpcbind=${cfg.rpc.address}
    rpcport=${toString cfg.rpc.port}
    rpcconnect=${cfg.rpc.address}
    ${optionalString (cfg.rpc.threads != null) "rpcthreads=${toString cfg.rpc.threads}"}
    rpcwhitelistdefault=0
    ${concatMapStrings (user: ''
        ${optionalString (!user.passwordHMACFromFile) "rpcauth=${user.name}:${passwordHMAC}"}
        ${optionalString (user.rpcwhitelist != [])
          "rpcwhitelist=${user.name}:${lib.strings.concatStringsSep "," user.rpcwhitelist}"}
      '') (builtins.attrValues cfg.rpc.users)
    }
    ${lib.concatMapStrings (rpcallowip: "rpcallowip=${rpcallowip}\n") cfg.rpc.allowip}

    # Wallet options
    ${optionalString (cfg.addresstype != null) "addresstype=${cfg.addresstype}"}

    # ZMQ options
    ${optionalString (cfg.zmqpubrawblock != null) "zmqpubrawblock=${cfg.zmqpubrawblock}"}
    ${optionalString (cfg.zmqpubrawtx != null) "zmqpubrawtx=${cfg.zmqpubrawtx}"}

    # Extra options
    ${cfg.extraConfig}
  '';
in {
  options = {
    services.bitcoind = {
      enable = mkEnableOption "Bitcoin daemon";
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen for peer connections.";
      };
      port = mkOption {
        type = types.port;
        default = 8333;
        description = "Port to listen for peer connections.";
      };
      getPublicAddressCmd = mkOption {
        type = types.str;
        default = "";
        description = ''
          Bash expression which outputs the public service address to announce to peers.
          If left empty, no address is announced.
        '';
      };
      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.bitcoind;
        defaultText = "pkgs.blockchains.bitcoind";
        description = "The package providing bitcoin binaries.";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        example = ''
          par=16
          logips=1
        '';
        description = "Additional configurations to be appended to <filename>bitcoin.conf</filename>.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/bitcoind";
        description = "The data directory for bitcoind.";
      };
      user = mkOption {
        type = types.str;
        default = "bitcoin";
        description = "The user as which to run bitcoind.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run bitcoind.";
      };
      rpc = {
        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = ''
            Address to listen for JSON-RPC connections.
          '';
        };
        port = mkOption {
          type = types.port;
          default = 8332;
          description = "Port to listen for JSON-RPC connections.";
        };
        threads = mkOption {
          type = types.nullOr types.ints.u16;
          default = null;
          description = "The number of threads to service RPC calls.";
        };
        allowip = mkOption {
          type = types.listOf types.str;
          default = [ "127.0.0.1" ];
          description = ''
            Allow JSON-RPC connections from specified sources.
          '';
        };
        users = mkOption {
          default = {};
          example = {
            alice.passwordHMAC = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
            bob.passwordHMAC = "b2dd077cb54591a2f3139e69a897ac$4e71f08d48b4347cf8eff3815c0e25ae2e9a4340474079f55705f40574f4ec99";
          };
          type = with types; loaOf (submodule ({ name, ... }: {
            options = {
              name = mkOption {
                type = types.str;
                default = name;
                example = "alice";
                description = ''
                  Username for JSON-RPC connections.
                '';
              };
              passwordHMAC = mkOption {
                type = types.str;
                example = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
                description = ''
                  Password HMAC-SHA-256 for JSON-RPC connections. Must be a string of the
                  format <SALT-HEX>$<HMAC-HEX>.
                '';
              };
              passwordHMACFromFile = mkOption {
                type = lib.types.bool;
                internal = true;
                default = false;
              };
              rpcwhitelist = mkOption {
                type = types.listOf types.str;
                default = [];
                description = ''
                  List of allowed rpc calls for each user.
                  If empty list, rpcwhitelist is disabled for that user.
                '';
              };
            };
          }));
          description = ''
            RPC user information for JSON-RPC connections.
          '';
        };
      };
      regtest = mkOption {
        type = types.bool;
        default = false;
        description = "Enable regtest mode.";
      };
      network = mkOption {
        readOnly = true;
        default = if cfg.regtest then "regtest" else "mainnet";
      };
      makeNetworkName = mkOption {
        readOnly = true;
        default = mainnet: regtest: if cfg.regtest then regtest else mainnet;
      };
      proxy = mkOption {
        type = types.nullOr types.str;
        default = if cfg.enforceTor then config.services.tor.client.socksListenAddress else null;
        description = "Connect through SOCKS5 proxy";
      };
      listen = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If enabled, the bitcoin service will listen.
        '';
      };
      dataDirReadableByGroup = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If enabled, data dir content is readable by the bitcoind service group.
          Warning: This disables bitcoind's wallet support.
        '';
      };
      sysperms = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Create new files with system default permissions, instead of umask 077
          (only effective with disabled wallet functionality)
        '';
      };
      disablewallet = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Do not load the wallet and disable wallet RPC calls
        '';
      };
      dbCache = mkOption {
        type = types.nullOr (types.ints.between 4 16384);
        default = null;
        example = 4000;
        description = "Override the default database cache size in megabytes.";
      };
      prune = mkOption {
        type = types.ints.unsigned;
        default = 0;
        example = 10000;
        description = ''
          Reduce storage requirements by enabling pruning (deleting) of old
          blocks. This allows the pruneblockchain RPC to be called to delete
          specific blocks, and enables automatic pruning of old blocks if a
          target size in MiB is provided. This mode is incompatible with -txindex
          and -rescan. Warning: Reverting this setting requires re-downloading
          the entire blockchain. ("disable" = disable pruning blocks, "manual"
          = allow manual pruning via RPC, >=550 = automatically prune block files
          to stay under the specified target size in MiB)
        '';
      };
      zmqpubrawblock = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "tcp://127.0.0.1:28332";
        description = "ZMQ address for zmqpubrawblock notifications";
      };
      zmqpubrawtx = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "tcp://127.0.0.1:28333";
        description = "ZMQ address for zmqpubrawtx notifications";
      };
      assumevalid = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "00000000000000000000e5abc3a74fe27dc0ead9c70ea1deb456f11c15fd7bc6";
        description = ''
          If this block is in the chain assume that it and its ancestors are
          valid and potentially skip their script verification.
        '';
      };
      addnodes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "ecoc5q34tmbq54wl.onion" ];
        description = "Add nodes to connect to and attempt to keep the connections open";
      };
      discover = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Discover own IP addresses";
      };
      addresstype = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "bech32";
        description = "What type of addresses to use";
      };
      cli = mkOption {
        readOnly = true;
        type = types.package;
        default = pkgs.writeScriptBin "bitcoin-cli" ''
          exec ${cfg.package}/bin/bitcoin-cli -datadir='${cfg.dataDir}' "$@"
        '';
        description = "Binary to connect with the bitcoind instance.";
      };
      enforceTor =  nix-bitcoin-services.enforceTor;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    services.bitcoind = mkMerge [
      (mkIf cfg.dataDirReadableByGroup {
        disablewallet = true;
        sysperms = true;
      })
      {
        rpc.users.privileged = {
          passwordHMACFromFile = true;
        };
        rpc.users.public = {
          passwordHMACFromFile = true;
          rpcwhitelist = import ./bitcoind-rpc-public-whitelist.nix;
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.dataDir}/blocks' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.bitcoind = {
      description = "Bitcoin daemon";
      requires = [ "nix-bitcoin-secrets.target" ];
      after = [ "network.target" "nix-bitcoin-secrets.target" ];
      wantedBy = [ "multi-user.target" ];
      preStart = let
        extraRpcauth = concatMapStrings (name: let
          user = cfg.rpc.users.${name};
        in optionalString user.passwordHMACFromFile ''
            echo "rpcauth=${user.name}:$(cat ${secretsDir}/bitcoin-HMAC-${name})"
          ''
        ) (builtins.attrNames cfg.rpc.users);
      in ''
        ${optionalString cfg.dataDirReadableByGroup "chmod -R g+rX '${cfg.dataDir}/blocks'"}
        cfg=$(
          cat ${configFile};
          ${extraRpcauth}
          ${/* Enable bitcoin-cli for group 'bitcoin' */ ""}
          printf "rpcuser=${cfg.rpc.users.privileged.name}\nrpcpassword="; cat "${secretsDir}/bitcoin-rpcpassword-privileged";
          echo
          ${optionalString (cfg.getPublicAddressCmd != "") ''
            echo "externalip=$(${cfg.getPublicAddressCmd})"
          ''}
        )
        confFile='${cfg.dataDir}/bitcoin.conf'
        if [[ ! -e $confFile || $cfg != $(cat $confFile) ]]; then
          install -o '${cfg.user}' -g '${cfg.group}' -m 640 <(echo "$cfg") $confFile
        fi
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        Type = "notify";
        NotifyAccess = "all";
        User = "${cfg.user}";
        Group = "${cfg.group}";
        TimeoutStartSec = 300;
        ExecStart = "${cfg.package}/bin/bitcoind -datadir='${cfg.dataDir}'";
        Restart = "on-failure";
        UMask = mkIf cfg.dataDirReadableByGroup "0027";
        ReadWritePaths = "${cfg.dataDir}";
      } // (if cfg.enforceTor
            then nix-bitcoin-services.allowTor
            else nix-bitcoin-services.allowAnyIP)
        // optionalAttrs (cfg.zmqpubrawblock != null || cfg.zmqpubrawtx != null) nix-bitcoin-services.allowAnyProtocol;
    };

    # Use this to update the banlist:
    # wget https://people.xiph.org/~greg/banlist.cli.txt
    systemd.services.bitcoind-import-banlist = {
      description = "Bitcoin daemon banlist importer";
      wantedBy = [ "bitcoind.service" ];
      bindsTo = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      script = ''
        cd ${cfg.cli}/bin
        echo "Importing node banlist..."
        cat ${./banlist.cli.txt} | while read line; do
            if ! err=$(eval "$line" 2>&1) && [[ $err != *already\ banned* ]]; then
                # unexpected error
                echo "$err"
                exit 1
            fi
        done
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        User = "${cfg.user}";
        Group = "${cfg.group}";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };

    users.users.${cfg.user} = {
      group = cfg.group;
      description = "Bitcoin daemon user";
    };
    users.groups.${cfg.group} = {};
    users.groups.bitcoinrpc = {};
    nix-bitcoin.operator.groups = [ cfg.group ];

    nix-bitcoin.secrets.bitcoin-rpcpassword-privileged.user = "bitcoin";
    nix-bitcoin.secrets.bitcoin-rpcpassword-public = {
      user = "bitcoin";
      group = "bitcoinrpc";
    };

    nix-bitcoin.secrets.bitcoin-HMAC-privileged.user = "bitcoin";
    nix-bitcoin.secrets.bitcoin-HMAC-public.user = "bitcoin";
  };
}
