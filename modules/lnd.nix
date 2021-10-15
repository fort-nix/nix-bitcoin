{ config, lib, pkgs, ... }:

with lib;
let
  options.services.lnd = {
    enable = mkEnableOption "Lightning Network Daemon";
    address = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to listen for peer connections";
    };
    port = mkOption {
      type = types.port;
      default = 9735;
      description = "Port to listen for peer connections";
    };
    rpcAddress = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to listen for RPC connections.";
    };
    rpcPort = mkOption {
      type = types.port;
      default = 10009;
      description = "Port to listen for gRPC connections.";
    };
    restAddress = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to listen for REST connections.";
    };
    restPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen for REST connections.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lnd";
      description = "The data directory for LND.";
    };
    networkDir = mkOption {
      readOnly = true;
      default = "${cfg.dataDir}/chain/bitcoin/${bitcoind.network}";
      description = "The network data directory.";
    };
    tor-socks = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.nix-bitcoin.torClientAddressWithPort else null;
      description = "Socks proxy for connecting to Tor nodes";
    };
    macaroons = mkOption {
      default = {};
      type = with types; attrsOf (submodule {
        options = {
          user = mkOption {
            type = types.str;
            description = "User who owns the macaroon.";
          };
          permissions = mkOption {
            type = types.str;
            example = ''
              {"entity":"info","action":"read"},{"entity":"onchain","action":"read"}
            '';
            description = "List of granted macaroon permissions.";
          };
        };
      });
      description = ''
        Extra macaroon definitions.
      '';
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        autopilot.active=1
      '';
      description = "Extra lines appended to <filename>lnd.conf</filename>.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.lnd;
      description = "The package providing lnd binaries.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "lncli"
        # Switch user because lnd makes datadir contents readable by user only
        ''
          ${runAsUser} ${cfg.user} ${cfg.package}/bin/lncli \
            --rpcserver ${cfg.rpcAddress}:${toString cfg.rpcPort} \
            --tlscertpath '${cfg.certPath}' \
            --macaroonpath '${networkDir}/admin.macaroon' "$@"
        '';
      description = "Binary to connect with the lnd instance.";
    };
    getPublicAddressCmd = mkOption {
      type = types.str;
      default = "";
      description = ''
        Bash expression which outputs the public service address to announce to peers.
        If left empty, no address is announced.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "lnd";
      description = "The user as which to run LND.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run LND.";
    };
    certPath = mkOption {
      readOnly = true;
      default = "${secretsDir}/lnd-cert";
      description = "LND TLS certificate path.";
    };
    inherit (nbLib) enforceTor;
  };

  cfg = config.services.lnd;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  bitcoind = config.services.bitcoind;

  bitcoindRpcAddress = nbLib.address bitcoind.rpc.address;
  networkDir = cfg.networkDir;
  configFile = pkgs.writeText "lnd.conf" ''
    datadir=${cfg.dataDir}
    logdir=${cfg.dataDir}/logs
    tlscertpath=${cfg.certPath}
    tlskeypath=${secretsDir}/lnd-key

    listen=${toString cfg.address}:${toString cfg.port}
    rpclisten=${cfg.rpcAddress}:${toString cfg.rpcPort}
    restlisten=${cfg.restAddress}:${toString cfg.restPort}

    bitcoin.${bitcoind.network}=1
    bitcoin.active=1
    bitcoin.node=bitcoind

    ${optionalString (cfg.enforceTor) "tor.active=true"}
    ${optionalString (cfg.tor-socks != null) "tor.socks=${cfg.tor-socks}"}

    bitcoind.rpchost=${bitcoindRpcAddress}:${toString bitcoind.rpc.port}
    bitcoind.rpcuser=${bitcoind.rpc.users.public.name}
    bitcoind.zmqpubrawblock=${bitcoind.zmqpubrawblock}
    bitcoind.zmqpubrawtx=${bitcoind.zmqpubrawtx}

    ${cfg.extraConfig}
  '';
in {

  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.prune == 0;
        message = "lnd does not support bitcoind pruning.";
      }
      { assertion =
          !(config.services ? clightning)
          || !config.services.clightning.enable
          || config.services.clightning.port != cfg.port;
        message = ''
          LND and clightning can't both bind to lightning port 9735. Either
          disable LND/clightning or change services.clightning.port or
          services.lnd.port to a port other than 9735.
        '';
      }
    ];

    services.bitcoind = {
      enable = true;

      # Increase rpc thread count due to reports that lightning implementations fail
      # under high bitcoind rpc load
      rpc.threads = 16;

      zmqpubrawblock = "tcp://${bitcoindRpcAddress}:28332";
      zmqpubrawtx = "tcp://${bitcoindRpcAddress}:28333";
    };

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.lnd = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        install -m600 ${configFile} '${cfg.dataDir}/lnd.conf'
        {
          echo "bitcoind.rpcpass=$(cat ${secretsDir}/bitcoin-rpcpassword-public)"
          ${optionalString (cfg.getPublicAddressCmd != "") ''
            echo "externalip=$(${cfg.getPublicAddressCmd})"
          ''}
        } >> '${cfg.dataDir}/lnd.conf'
      '';
      serviceConfig = nbLib.defaultHardening // {
        RuntimeDirectory = "lnd"; # Only used to store custom macaroons
        RuntimeDirectoryMode = "711";
        ExecStart = "${cfg.package}/bin/lnd --configfile=${cfg.dataDir}/lnd.conf";
        User = cfg.user;
        TimeoutSec = "15min";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
        ExecStartPost = let
          # Retrying is necessary because it can happen that the lnd socket is
          # existing, but the RPC service isn't yet, which results in error
          # "waiting to start, RPC services not available".
          curl = "${pkgs.curl}/bin/curl -s --show-error --retry 10 --cacert ${cfg.certPath}";
          restUrl = "https://${nbLib.addressWithPort cfg.restAddress cfg.restPort}/v1";
        in [
          (nbLib.script "lnd-create-wallet" ''
            attempts=250
            while ! {
              exec 3>/dev/tcp/${nbLib.address cfg.restAddress}/${toString cfg.restPort} && exec 3>&-
            } &>/dev/null; do
              ((attempts-- == 0)) && { echo "lnd REST service unreachable"; exit 1; }
              sleep 0.1
            done

            if [[ ! -f ${networkDir}/wallet.db ]]; then
              mnemonic="${cfg.dataDir}/lnd-seed-mnemonic"
              if [[ ! -f "$mnemonic" ]]; then
                echo "Create lnd seed"
                umask u=r,go=
                ${curl} -X GET ${restUrl}/genseed | ${pkgs.jq}/bin/jq -c '.cipher_seed_mnemonic' > "$mnemonic"
              fi

              echo "Create lnd wallet"
              ${curl} --output /dev/null \
                -X POST -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\", \
                \"cipher_seed_mnemonic\": $(cat "$mnemonic" | tr -d '\n')}" \
                ${restUrl}/initwallet

              # Guarantees that RPC calls with cfg.cli succeed after the service is started
              echo "Wait until wallet is created"
              while [[ ! -f ${networkDir}/admin.macaroon ]]; do
                sleep 0.1
              done
            else
              echo "Unlock lnd wallet"
              ${curl} \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${networkDir}/admin.macaroon')" \
                -X POST \
                -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\"}" \
                ${restUrl}/unlockwallet
            fi
            # Wait until the wallet has been unlocked and RPC is fully active
            while [[ $(${curl} -d '{}' -X POST ${restUrl}/state | ${pkgs.jq}/bin/jq -r '.state') != RPC_ACTIVE ]]; do
              sleep 0.1
            done
          '')
          # Setting macaroon permission for other users needs root permissions
          (nbLib.rootScript "lnd-create-macaroons" ''
            umask ug=r,o=
            ${lib.concatMapStrings (macaroon: ''
              echo "Create custom macaroon ${macaroon}"
              macaroonPath="$RUNTIME_DIRECTORY/${macaroon}.macaroon"
              ${curl} \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${networkDir}/admin.macaroon')" \
                -X POST \
                -d '{"permissions":[${cfg.macaroons.${macaroon}.permissions}]}' \
                ${restUrl}/macaroon |\
                ${pkgs.jq}/bin/jq -c '.macaroon' | ${pkgs.xxd}/bin/xxd -p -r > "$macaroonPath"
              chown ${cfg.macaroons.${macaroon}.user}: "$macaroonPath"
            '') (attrNames cfg.macaroons)}
          '')
        ];
      } // nbLib.allowedIPAddresses cfg.enforceTor;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
      home = cfg.dataDir; # lnd creates .lnd dir in HOME
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      allowRunAsUsers = [ cfg.user ];
    };

    nix-bitcoin.secrets = {
      lnd-wallet-password.user = cfg.user;
      lnd-key.user = cfg.user;
      lnd-cert.user = cfg.user;
      lnd-cert.permissions = "444"; # world readable
    };
    # Advantages of manually pre-generating certs:
    # - Reduces dynamic state
    # - Enables deployment of a mesh of server plus client nodes with predefined certs
    nix-bitcoin.generateSecretsCmds.lnd = ''
      makePasswordSecret lnd-wallet-password
      makeCert lnd '${optionalString (cfg.rpcAddress != "localhost") "IP:${cfg.rpcAddress}"}'
    '';
  };
}
