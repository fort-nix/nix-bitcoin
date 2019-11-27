{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lnd;
  inherit (config) nix-bitcoin-services;
  configFile = pkgs.writeText "lnd.conf" ''
    datadir=${cfg.dataDir}
    logdir=${cfg.dataDir}/logs
    bitcoin.mainnet=1
    tlscertpath=/secrets/lnd_cert
    tlskeypath=/secrets/lnd_key

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
    cli = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "lncli"
      # Switch user because lnd makes datadir contents readable by user only
      ''
        exec sudo -u lnd ${pkgs.nix-bitcoin.lnd}/bin/lncli --tlscertpath /secrets/lnd_cert \
          --macaroonpath '${cfg.dataDir}/chain/bitcoin/mainnet/admin.macaroon' "$@"
      '';
      description = "Binary to connect with the lnd instance.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    users.users.lnd = {
        description = "LND User";
        group = "lnd";
        extraGroups = [ "bitcoinrpc" ];
        home = cfg.dataDir;
    };
    users.groups.lnd = {};

    systemd.services.lnd = {
      description = "Run LND";
      path  = [ pkgs.nix-bitcoin.bitcoind ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        mkdir -m 0770 -p ${cfg.dataDir}
        cp ${configFile} ${cfg.dataDir}/lnd.conf
        chown -R 'lnd:lnd' '${cfg.dataDir}'
        chmod u=rw,g=r,o= ${cfg.dataDir}/lnd.conf
        echo "bitcoind.rpcpass=$(cat /secrets/bitcoin-rpcpassword)" >> '${cfg.dataDir}/lnd.conf'
      '';
      serviceConfig = {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.nix-bitcoin.lnd}/bin/lnd --configfile=${cfg.dataDir}/lnd.conf";
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening
        // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP
        ) // nix-bitcoin-services.allowAnyProtocol;  # For ZMQ
      postStart = ''
        umask 377

        attempts=50
        while ! { exec 3>/dev/tcp/127.0.0.1/8080 && exec 3>&-; } &>/dev/null; do
              ((attempts-- == 0)) && { echo "lnd REST service unreachable"; exit 1; }
              sleep 0.1
        done

        if [[ ! -f /secrets/lnd-seed-mnemonic ]]; then
          echo Creating lnd seed

          ${pkgs.curl}/bin/curl -s \
            --cacert /secrets/lnd_cert \
            -X GET https://127.0.0.1:8080/v1/genseed | ${pkgs.jq}/bin/jq -c '.cipher_seed_mnemonic' > /secrets/lnd-seed-mnemonic
        fi

        if [[ ! -f ${cfg.dataDir}/chain/bitcoin/mainnet/wallet.db ]]; then
          echo Creating lnd wallet

          ${pkgs.curl}/bin/curl -s --output /dev/null --show-error \
            --cacert /secrets/lnd_cert \
            -X POST -d "{\"wallet_password\": \"$(cat /secrets/lnd-wallet-password | tr -d '\n' | base64 -w0)\", \
            \"cipher_seed_mnemonic\": $(cat /secrets/lnd-seed-mnemonic | tr -d '\n')}" \
            https://127.0.0.1:8080/v1/initwallet
        else
          echo Unlocking lnd wallet

          ${pkgs.curl}/bin/curl -s \
            -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 ${cfg.dataDir}/chain/bitcoin/mainnet/admin.macaroon)" \
            --cacert /secrets/lnd_cert \
            -X POST \
            -d "{\"wallet_password\": \"$(cat /secrets/lnd-wallet-password | tr -d '\n' | base64 -w0)\"}" \
            https://127.0.0.1:8080/v1/unlockwallet
        fi
      '';
    };
  };
}
