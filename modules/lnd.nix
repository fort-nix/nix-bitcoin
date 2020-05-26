{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lnd;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
  configFile = pkgs.writeText "lnd.conf" ''
    datadir=${cfg.dataDir}
    logdir=${cfg.dataDir}/logs
    bitcoin.mainnet=1
    tlscertpath=${secretsDir}/lnd-cert
    tlskeypath=${secretsDir}/lnd-key

    rpclisten=localhost:${toString cfg.rpcPort}

    bitcoin.active=1
    bitcoin.node=bitcoind

    tor.active=true
    tor.v3=true
    tor.streamisolation=true
    tor.privatekeypath=${cfg.dataDir}/v3_onion_private_key

    bitcoind.rpcuser=${config.services.bitcoind.rpcuser}
    bitcoind.zmqpubrawblock=${config.services.bitcoind.zmqpubrawblock}
    bitcoind.zmqpubrawtx=${config.services.bitcoind.zmqpubrawtx}

    ${cfg.extraConfig}
  '';
in {

  options.services.lnd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the LND service will be installed.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lnd";
      description = "The data directory for LND.";
    };
    rpcPort = mkOption {
      type = types.ints.u16;
      default = 10009;
      description = "Port on which to listen for gRPC connections.";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        autopilot.active=1
      '';
      description = "Additional configurations to be appended to <filename>lnd.conf</filename>.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.nix-bitcoin.lnd;
      defaultText = "pkgs.nix-bitcoin.lnd";
      description = "The package providing lnd binaries.";
    };
    cli = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "lncli"
      # Switch user because lnd makes datadir contents readable by user only
      ''
        exec sudo -u lnd ${cfg.package}/bin/lncli --tlscertpath ${secretsDir}/lnd-cert \
          --macaroonpath '${cfg.dataDir}/chain/bitcoin/mainnet/admin.macaroon' "$@"
      '';
      description = "Binary to connect with the lnd instance.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 lnd lnd - -"
    ];

    services.bitcoind = {
      zmqpubrawblock = "tcp://127.0.0.1:28332";
      zmqpubrawtx = "tcp://127.0.0.1:28333";
    };

    systemd.services.lnd = {
      description = "Run LND";
      path  = [ pkgs.nix-bitcoin.bitcoind ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        install -m600 ${configFile} '${cfg.dataDir}/lnd.conf'
        echo "bitcoind.rpcpass=$(cat ${secretsDir}/bitcoin-rpcpassword)" >> '${cfg.dataDir}/lnd.conf'
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = "${cfg.package}/bin/lnd --configfile=${cfg.dataDir}/lnd.conf";
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
        ExecStartPost = [
          # Run fully privileged for secrets dir write access
          "+${nix-bitcoin-services.script ''
            attempts=50
            while ! { exec 3>/dev/tcp/127.0.0.1/8080 && exec 3>&-; } &>/dev/null; do
                  ((attempts-- == 0)) && { echo "lnd REST service unreachable"; exit 1; }
                  sleep 0.1
            done

            mnemonic=${secretsDir}/lnd-seed-mnemonic
            if [[ ! -f $mnemonic ]]; then
              echo Create lnd seed

              ${pkgs.curl}/bin/curl -s \
                --cacert ${secretsDir}/lnd-cert \
                -X GET https://127.0.0.1:8080/v1/genseed | ${pkgs.jq}/bin/jq -c '.cipher_seed_mnemonic' > "$mnemonic"
            fi
            chown lnd: "$mnemonic"
            chmod 400 "$mnemonic"
          ''}"
          "${let
            mainnetDir = "${cfg.dataDir}/chain/bitcoin/mainnet";
          in nix-bitcoin-services.script ''
            if [[ ! -f ${mainnetDir}/wallet.db ]]; then
              echo Create lnd wallet

              ${pkgs.curl}/bin/curl -s --output /dev/null --show-error \
                --cacert ${secretsDir}/lnd-cert \
                -X POST -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\", \
                \"cipher_seed_mnemonic\": $(cat ${secretsDir}/lnd-seed-mnemonic | tr -d '\n')}" \
                https://127.0.0.1:8080/v1/initwallet

              # Guarantees that RPC calls with cfg.cli succeed after the service is started
              echo Wait until wallet is created
              while [[ ! -f ${mainnetDir}/admin.macaroon ]]; do
                sleep 0.1
              done
            else
              echo Unlock lnd wallet

              ${pkgs.curl}/bin/curl -s \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${mainnetDir}/admin.macaroon')" \
                --cacert ${secretsDir}/lnd-cert \
                -X POST \
                -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\"}" \
                https://127.0.0.1:8080/v1/unlockwallet
            fi

            # Wait until the RPC port is open
            while ! { exec 3>/dev/tcp/127.0.0.1/${toString cfg.rpcPort}; } &>/dev/null; do
              sleep 0.1
            done
          ''}"
        ];
      } // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP
        ) // nix-bitcoin-services.allowAnyProtocol;  # For ZMQ
    };
    users.users.lnd = {
      description = "LND User";
      group = "lnd";
      extraGroups = [ "bitcoinrpc" ];
      home = cfg.dataDir; # lnd creates .lnd dir in HOME
    };
    users.groups.lnd = {};
    nix-bitcoin.secrets = {
      lnd-wallet-password.user = "lnd";
      lnd-key.user = "lnd";
      lnd-cert.user = "lnd";
    };
  };
}
