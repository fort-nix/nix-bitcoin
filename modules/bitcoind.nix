{ config, pkgs, lib, ... }:

with lib;
let
  options = {
    services.bitcoind = {
      enable = mkEnableOption "Bitcoin daemon";
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen for peer connections.";
      };
      package = mkOption {
        type = types.package;
        default = if cfg.implementation == "knots" then pkgs.bitcoin-knots else pkgs.bitcoind;
        defaultText = "pkgs.bitcoind or pkgs.bitcoin-knots based on implementation";
        description = "The package to use.";
      };
      port = mkOption {
        type = types.port;
        default = if !cfg.regtest then 8333 else 18444;
        defaultText = "if !cfg.regtest then 8333 else 18444";
        description = "Port to listen for peer connections.";
      };
      onionPort = mkOption {
        type = types.nullOr types.port;
        # When the bitcoind onion service is enabled, add an onion-tagged socket
        # to distinguish local connections from Tor connections
        default = if (config.nix-bitcoin.onionServices.bitcoind.enable or false) then 8334 else null;
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
        default = 8335;
        description = "See `listenWhitelisted`.";
      };
      getPublicAddressCmd = mkOption {
        type = types.str;
        default = "";
        description = ''
          Bash expression which outputs the public service address to announce to peers.
          If left empty, no address is announced.
        '';
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        example = ''
          par=16
          logips=1
        '';
        description = "Extra lines appended to {file}`bitcoin.conf`.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/bitcoind";
        description = "The data directory for bitcoind.";
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
          default = if !cfg.regtest then 8332 else 18443;
          defaultText = "if !cfg.regtest then 8332 else 18443";
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
          description = ''
            Allowed users for JSON-RPC connections.
          '';
          example = {
            alice = {
              passwordHMAC = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
              rpcwhitelist = [ "sendtoaddress" "getnewaddress" ];
            };
          };
          type = with types; attrsOf (submodule ({ name, ... }: {
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
                  format `<SALT-HEX>$<HMAC-HEX>`.
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
        default = if cfg.tor.proxy then config.nix-bitcoin.torClientAddressWithPort else null;
        description = "Connect through SOCKS5 proxy";
      };
      i2p = mkOption {
        type = types.enum [ false true "only-outgoing" ];
        default = false;
        description = ''
          Enable peer connections via i2p.
          With `only-outgoing`, incoming i2p connections are disabled.
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
        description = "Override the default database cache size in MiB.";
      };
      prune = mkOption {
        type = types.ints.unsigned;
        default = 0;
        example = 10000;
        description = ''
          Automatically prune block files to stay under the specified target size in MiB.
          Value 0 disables pruning.
        '';
      };
      txindex = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the transaction index.";
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
        description = "The type of addresses to use";
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
      implementation = mkOption {
        type = types.enum [ "core" "knots" ];
        default = "core";
        description = ''
          Select the Bitcoin implementation to use.
          `core`: Use the standard Bitcoin Core package.
          `knots`: Use the Bitcoin Knots package.
        '';
      };
      cli = mkOption {
        readOnly = true;
        type = types.package;
        default = pkgs.writers.writeBashBin "bitcoin-cli" ''
          exec ${cfg.package}/bin/bitcoin-cli -datadir='${cfg.dataDir}' "$@"
        '';
        defaultText = "(See source)";
        description = "Binary to connect with the bitcoind instance.";
      };

      knotsSpecificOptions = mkIf (cfg.implementation == "knots") (mkOption {
        type = types.attrsOf types.anything;
        default = {};
        example = { # Example Knots-specific options with Nix types
          # -- Options often differing from Core defaults or specific to Knots --
          mempoolfullrbf = true;            # Opt-in to full RBF logic
          acceptnonstdtxn = true;           # Accept (but do not relay) non-standard transactions
          permitbarepubkey = true;          # Permit bare P2PK outputs
          spkreuse = false;                 # Disallow scriptPubKey reuse in mempool (false = "conflict")
          dbfilesize = 128;                 # Control LevelDB target file size (MiB)
          corepolicy = false;               # Don't use Core policy defaults (explicitly use Knots defaults)
          mempoolreplacement = "fee,-optin"; # Always allow RBF (Knots default)
          rejectparasites = true;           # Refuse parasitic overlay protocols (Knots default)
          rejecttokens = true;              # Refuse non-bitcoin token transactions (Knots default)

          # -- General options not exposed via dedicated Nix attrs --
          # Network/Blocks/Mempool related
          allowignoredconf = true;          # Treat unused conf as warning
          blockfilterindex = "basic";       # Maintain compact block filter index ("basic", "v0")
          blockreconstructionextratxn = 100;# Extra txns for compact block reconstruction
          blocksdir = "/path/to/blocks";    # Custom directory for block data
          blocksxor = true;                 # XOR key for block files
          coinstatsindex = true;            # Maintain coinstats index
          loadblock = "/path/to/blocks.dat";# Import blocks from external file on startup
          lowmem = 10;                      # Flush caches if memory below <n> MiB
          persistmempoolv1 = false;         # Use current mempool.dat format
          pruneduringinit = 1;              # Temporary prune setting during initial sync (if prune enabled)
          asmap = "ip_asn.map";             # ASN mapping file
          acceptnonstddatacarrier = false;  # Relay non-OP_RETURN datacarrier
          bytespersigop = 20;               # Equivalent bytes per sigop
          bytespersigopstrict = 20;         # Minimum bytes per sigop strict
          datacarrier = true;               # Relay data carrier transactions
          datacarriercost = 1;              # VBytes cost multiplier for extra data
          datacarriersize = 42;             # Max size for data carrier txns (bytes)
          dustdynamic = "3*mempool:1000"; # Automatically adjust dust relay fee
          maxscriptsize = 1650;             # Maximum script size relayed/mined (bytes)
          mempooltruc = "accept";           # TRUC limit behavior ("accept", "reject", "enforce")
          permitbaremultisig = false;       # Relay non-P2SH multisig outputs
          blockmaxsize = 300000;            # Maximum block size (bytes)
          blockprioritysize = 100000;       # Max size high-priority/low-fee txns (bytes)

          # Wallet related (if wallet enabled)
          walletimplicitsegwit = false;     # Support segwit when importing/restoring legacy wallets

          # Logging/Misc related
          uaappend = "my-knots-node";      # Append a string to the node's user agent
          uacomment = "my-comment";         # Append comment to the user agent string
          loglevelalways = false;           # Always prepend log level

          # Statistics related
          statsenable = false;              # Enable statistics
          statsmaxmemorytarget = 10485760;  # Memory limit for statistics (bytes)

          # Less common/Internal (usually not needed)
          # confrw = "bitcoin_rw.conf";
          # settings = "settings.json";
        };
        description = "Bitcoin Knots specific configuration options added to bitcoin.conf.";
      });

      tor = nbLib.tor;
    };
  };

  cfg = config.services.bitcoind;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  i2pSAM = config.services.i2pd.proto.sam;

  configFile = builtins.toFile "bitcoin.conf" ''
    # We're already logging via journald
    nodebuglogfile=1
    logtimestamps=0

    startupnotify=/run/current-system/systemd/bin/systemd-notify --ready

    ${optionalString cfg.regtest ''
      regtest=1
      [regtest]
    ''}
    ${optionalString (cfg.dbCache != null) "dbcache=${toString cfg.dbCache}"}
    prune=${toString cfg.prune}
    ${optionalString cfg.txindex "txindex=1"}
    ${optionalString (cfg.sysperms != null) "sysperms=${if cfg.sysperms then "1" else "0"}"}
    ${optionalString (cfg.disablewallet != null) "disablewallet=${if cfg.disablewallet then "1" else "0"}"}
    ${optionalString (cfg.assumevalid != null) "assumevalid=${cfg.assumevalid}"}

    # Connection options
    listen=${if (cfg.listen || cfg.listenWhitelisted) then "1" else "0"}
    ${optionalString cfg.listen
      "bind=${cfg.address}:${toString cfg.port}"}
    ${optionalString (cfg.listen && cfg.onionPort != null)
      "bind=${cfg.address}:${toString cfg.onionPort}=onion"}
    ${optionalString cfg.listenWhitelisted
      "whitebind=${cfg.address}:${toString cfg.whitelistedPort}"}
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}
    ${optionalString (cfg.i2p != false) "i2psam=${nbLib.addressWithPort i2pSAM.address i2pSAM.port}"}
    ${optionalString (cfg.i2p == "only-outgoing") "i2pacceptincoming=0"}

    ${optionalString (cfg.discover != null) "discover=${if cfg.discover then "1" else "0"}"}
    ${lib.concatMapStrings (node: "addnode=${node}\n") cfg.addnodes}

    # RPC server options
    rpcbind=${cfg.rpc.address}
    rpcport=${toString cfg.rpc.port}
    rpcconnect=${cfg.rpc.address}
    ${optionalString (cfg.rpc.threads != null) "rpcthreads=${toString cfg.rpc.threads}"}
    rpcwhitelistdefault=0
    ${concatMapStrings (user: ''
        ${optionalString (!user.passwordHMACFromFile) "rpcauth=${user.name}:${user.passwordHMAC}"}
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

    # Generic extra options
    ${cfg.extraConfig}

    # Knots-specific extra options - handle type conversion
    ${lib.optionalString (cfg.implementation == "knots") (lib.concatStringsSep "\n" (
      mapAttrsToList (name: value:
        let
          valStr = if isBool value then (if value then "1" else "0")
                   else if isInt value then toString value
                   else toString value; # Default to string conversion
        in "${name}=${valStr}"
      ) cfg.knotsSpecificOptions
    ))}

    ${extraRpcauth}
  '';

  zmqServerEnabled = (cfg.zmqpubrawblock != null) || (cfg.zmqpubrawtx != null);
in {
  inherit options;

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

    services.i2pd = mkIf (cfg.i2p != false) {
      enable = true;
      proto.sam.enable = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.bitcoind = rec {
      wants = [
        "network-online.target"
        # Use `wants` instead of `requires` for `nix-bitcoin-secrets.target`
        # so that bitcoind and all dependent services are not restarted when
        # the secrets target restarts.
        # The secrets target always restarts when deploying with one of the methods
        # in ./deployment.
        #
        # TODO-EXTERNAL: Instead of `wants`, use a future systemd dependency type
        # that propagates initial start failures but no restarts
        "nix-bitcoin-secrets.target"
      ];
      after = wants;
      wantedBy = [ "multi-user.target" ];

      description = if cfg.implementation == "knots" then "Bitcoin Knots daemon" else "Bitcoin Core daemon";

      environment.BITCOIN_DATADIR = cfg.dataDir;
      # Add secrets to path for rpcauth files read by bitcoind
      preStart = let
        extraRpcauth = concatMapStrings (name: let
          user = cfg.rpc.users.${name};
        in optionalString user.passwordHMACFromFile ''
            echo "rpcauth=${user.name}:$(cat ${secretsDir}/bitcoin-HMAC-${name})"
          ''
        ) (builtins.attrNames cfg.rpc.users);
      in ''
        ${optionalString cfg.dataDirReadableByGroup ''
          if [[ -e '${cfg.dataDir}/blocks' ]]; then
            chmod -R g+rX '${cfg.dataDir}/blocks'
          fi
        ''}

        cfg=$(
          cat ${configFile}
          ${extraRpcauth}
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

      # Enable RPC access for group
      postStart = ''
        chmod g=r '${cfg.dataDir}/${optionalString cfg.regtest "regtest/"}.cookie'
      '' + (optionalString cfg.regtest) ''
        chmod g=x '${cfg.dataDir}/regtest'
      '';

      serviceConfig = nbLib.defaultHardening // {
        Type = "notify";
        NotifyAccess = "all";
        User = cfg.user;
        Group = cfg.group;
        TimeoutStartSec = "30min";
        TimeoutStopSec = "30min";
        ExecStart = "${cfg.package}/bin/bitcoind -datadir='${cfg.dataDir}'";
        Restart = "on-failure";
        UMask = mkIf cfg.dataDirReadableByGroup "0027";
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // optionalAttrs zmqServerEnabled nbLib.allowNetlink;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = {};
    users.groups.bitcoinrpc-public = {};

    nix-bitcoin.operator.groups = [ cfg.group ];

    nix-bitcoin.secrets = {
      bitcoin-rpcpassword-privileged.user = cfg.user;
      bitcoin-rpcpassword-public = {
        user = cfg.user;
        group = "bitcoinrpc-public";
      };

      bitcoin-HMAC-privileged.user = cfg.user;
      bitcoin-HMAC-public.user = cfg.user;
    };
    nix-bitcoin.generateSecretsCmds.bitcoind = ''
      makeBitcoinRPCPassword privileged
      makeBitcoinRPCPassword public
    '';
  };
}
