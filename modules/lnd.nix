{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lnd;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  bitcoind = config.services.bitcoind;
  bitcoindRpcAddress = bitcoind.rpc.address;
  networkDir = "${cfg.dataDir}/chain/bitcoin/${bitcoind.network}";
  configFile = pkgs.writeText "lnd.conf" ''
    datadir=${cfg.dataDir}
    logdir=${cfg.dataDir}/logs
    tlscertpath=${secretsDir}/lnd-cert
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

  options.services.lnd = {
    enable = mkEnableOption "Lightning Network Daemon";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lnd";
      description = "The data directory for LND.";
    };
    networkDir = mkOption {
      readOnly = true;
      default = networkDir;
      description = "The network data directory.";
    };
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
      description = ''
        Address to listen for REST connections.
      '';
    };
    restPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen for REST connections.";
    };
    tor-socks = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.services.tor.client.socksListenAddress else null;
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
        ${runAsUser} lnd ${cfg.package}/bin/lncli \
          --rpcserver ${cfg.rpcAddress}:${toString cfg.rpcPort} \
          --tlscertpath '${secretsDir}/lnd-cert' \
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
    inherit (nbLib) enforceTor;
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.prune == 0;
        message = "lnd does not support bitcoind pruning.";
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
      "d '${cfg.dataDir}' 0770 lnd lnd - -"
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
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
        ExecStartPost = let
          restUrl = "https://${cfg.restAddress}:${toString cfg.restPort}/v1";
        in [
          # Run fully privileged for secrets dir write access
          (nbLib.privileged "lnd-create-mnemonic" ''
            attempts=250
            while ! { exec 3>/dev/tcp/${cfg.restAddress}/${toString cfg.restPort} && exec 3>&-; } &>/dev/null; do
                  ((attempts-- == 0)) && { echo "lnd REST service unreachable"; exit 1; }
                  sleep 0.1
            done

            mnemonic=${secretsDir}/lnd-seed-mnemonic
            if [[ ! -f $mnemonic ]]; then
              echo Create lnd seed
              umask u=r,go=
              ${pkgs.curl}/bin/curl -s \
                --cacert ${secretsDir}/lnd-cert \
                -X GET ${restUrl}/genseed | ${pkgs.jq}/bin/jq -c '.cipher_seed_mnemonic' > "$mnemonic"
            fi
            chown lnd: "$mnemonic"
          '')
          (nbLib.script "lnd-create-wallet" ''
            if [[ ! -f ${networkDir}/wallet.db ]]; then
              echo Create lnd wallet

              ${pkgs.curl}/bin/curl -s --output /dev/null --show-error \
                --cacert ${secretsDir}/lnd-cert \
                -X POST -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\", \
                \"cipher_seed_mnemonic\": $(cat ${secretsDir}/lnd-seed-mnemonic | tr -d '\n')}" \
                ${restUrl}/initwallet

              # Guarantees that RPC calls with cfg.cli succeed after the service is started
              echo Wait until wallet is created
              while [[ ! -f ${networkDir}/admin.macaroon ]]; do
                sleep 0.1
              done
            else
              echo Unlock lnd wallet

              ${pkgs.curl}/bin/curl -s \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${networkDir}/admin.macaroon')" \
                --cacert ${secretsDir}/lnd-cert \
                -X POST \
                -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\"}" \
                ${restUrl}/unlockwallet
            fi

            # Wait until the RPC port is open
            while ! { exec 3>/dev/tcp/${cfg.rpcAddress}/${toString cfg.rpcPort}; } &>/dev/null; do
              sleep 0.1
            done

          '')
          # Run fully privileged for chown
          (nbLib.privileged "lnd-create-macaroons" ''
            umask ug=r,o=
            ${lib.concatMapStrings (macaroon: ''
              echo "Create custom macaroon ${macaroon}"
              macaroonPath="$RUNTIME_DIRECTORY/${macaroon}.macaroon"
              ${pkgs.curl}/bin/curl -s \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${networkDir}/admin.macaroon')" \
                --cacert ${secretsDir}/lnd-cert \
                -X POST \
                -d '{"permissions":[${cfg.macaroons.${macaroon}.permissions}]}' \
                ${restUrl}/macaroon |\
                ${pkgs.jq}/bin/jq -c '.macaroon' | ${pkgs.xxd}/bin/xxd -p -r > "$macaroonPath"
              chown ${cfg.macaroons.${macaroon}.user}: "$macaroonPath"
            '') (attrNames cfg.macaroons)}
          '')
        ];
      } // (if cfg.enforceTor
          then nbLib.allowTor
          else nbLib.allowAnyIP
        ) // nbLib.allowAnyProtocol;  # For ZMQ
    };

    users.users.lnd = {
      group = "lnd";
      extraGroups = [ "bitcoinrpc" ];
      home = cfg.dataDir; # lnd creates .lnd dir in HOME
    };
    users.groups.lnd = {};
    nix-bitcoin.operator = {
      groups = [ "lnd" ];
      allowRunAsUsers = [ "lnd" ];
    };

    nix-bitcoin.secrets = {
      lnd-wallet-password.user = "lnd";
      lnd-key.user = "lnd";
      lnd-cert.user = "lnd";
      lnd-cert.permissions = "0444"; # world readable
    };
  };
}
