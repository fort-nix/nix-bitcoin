{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.joinmarket;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;

  inherit (config.services) bitcoind;
  torAddress = builtins.head (builtins.split ":" config.services.tor.client.socksListenAddress);
  # Based on https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/jmclient/jmclient/configure.py
  configFile = builtins.toFile "config" ''
    [DAEMON]
    no_daemon = 0
    daemon_port = 27183
    daemon_host = localhost
    use_ssl = false

    [BLOCKCHAIN]
    blockchain_source = bitcoin-rpc
    network = ${bitcoind.network}
    rpc_host = ${bitcoind.rpcbind}
    rpc_port = ${toString bitcoind.rpc.port}
    rpc_user = ${bitcoind.rpc.users.privileged.name}
    @@RPC_PASSWORD@@

    [MESSAGING:server1]
    host = darksci3bfoka7tw.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050

    [MESSAGING:server2]
    host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
    channel = joinmarket-pit
    port = 6667
    usessl = false
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050

    [LOGGING]
    console_log_level = INFO
    color = false

    [POLICY]
    segwit = true
    native = false
    merge_algorithm = default
    tx_fees = 3
    absurd_fee_per_kb = 350000
    tx_broadcast = self
    minimum_makers = 4
    max_sats_freeze_reuse = -1
    taker_utxo_retries = 3
    taker_utxo_age = 5
    taker_utxo_amtpercent = 20
    accept_commitment_broadcasts = 1
    commit_file_location = cmtdata/commitments.json

    [PAYJOIN]
    payjoin_version = 1
    disable_output_substitution = 0
    max_additional_fee_contribution = default
    min_fee_rate = 1.1
    onion_socks5_host = ${torAddress}
    onion_socks5_port = 9050
    tor_control_host = unix:/run/tor/control
    hidden_service_ssl = false
  '';

   # The jm scripts create a 'logs' dir in the working dir,
   # so run them inside dataDir.
   cli = pkgs.runCommand "joinmarket-cli" {} ''
     mkdir -p $out/bin
     jm=${pkgs.nix-bitcoin.joinmarket}/bin
     cd $jm
     for bin in jm-*; do
       {
         echo "#!${pkgs.bash}/bin/bash";
         echo "cd '${cfg.dataDir}' && ${cfg.cliExec} sudo -u ${cfg.user} $jm/$bin --datadir='${cfg.dataDir}' \"\$@\"";
       } > $out/bin/$bin
     done
     chmod -R +x $out/bin
   '';
in {
  options.services.joinmarket = {
    enable = mkEnableOption "JoinMarket";
    yieldgenerator = {
      enable = mkEnableOption "yield generator bot";
      customParameters = mkOption {
        type = types.str;
        default = "";
        example = ''
          txfee = 200
          cjfee_a = 300
        '';
        description = ''
          Python code to define custom yield generator parameters, as described in
          https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/YIELDGENERATOR.md
        '';
      };
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/joinmarket";
      description = "The data directory for JoinMarket.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket";
      description = "The user as which to run JoinMarket.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run JoinMarket.";
    };
    cli = mkOption {
      default = cli;
    };
    inherit (nix-bitcoin-services) cliExec;
  };

  config = mkIf cfg.enable (mkMerge [{
    services.bitcoind.enable = true;

    environment.systemPackages = [
      (hiPrio cfg.cli)
    ];
    users.users.${cfg.user} = {
        description = "joinmarket User";
        group = "${cfg.group}";
        home = cfg.dataDir;
        extraGroups = [ "tor" ];
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      sudoUsers = [ cfg.group ];
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    services.bitcoind.disablewallet = false;

    # Joinmarket is TOR-only
    services.tor = {
      enable = true;
      client.enable = true;
      controlSocket.enable = true;
    };

    systemd.services.joinmarket = {
      description = "JoinMarket Daemon";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      path = [ pkgs.sudo ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStartPre = nix-bitcoin-services.privileged ''
          install -o '${cfg.user}' -g '${cfg.group}' -m 640 ${configFile} ${cfg.dataDir}/joinmarket.cfg
          sed -i \
             "s|@@RPC_PASSWORD@@|rpc_password = $(cat ${secretsDir}/bitcoin-rpcpassword-privileged)|" \
             '${cfg.dataDir}/joinmarket.cfg'
        '';
        # Generating wallets (jmclient/wallet.py) is only supported for mainnet or testnet
        ExecStartPost = mkIf (bitcoind.network == "mainnet") (nix-bitcoin-services.privileged ''
          walletname=wallet.jmdat
          pw=$(cat "${secretsDir}"/jm-wallet-password)
          mnemonic=${secretsDir}/jm-wallet-seed
          if [[ ! -f ${cfg.dataDir}/wallets/$walletname ]]; then
            echo Create joinmarket wallet
            # Use bash variables so commands don't proceed on previous failures
            # (like with pipes)
            cd ${cfg.dataDir} && \
              out=$(sudo -u ${cfg.user} \
              ${pkgs.nix-bitcoin.joinmarket}/bin/jm-genwallet \
              --datadir=${cfg.dataDir} $walletname $pw)
            recoveryseed=$(echo "$out" | grep 'recovery_seed')
            echo "$recoveryseed" | cut -d ':' -f2 > $mnemonic
          fi
        '');
        ExecStart = "${pkgs.nix-bitcoin.joinmarket}/bin/joinmarketd";
        WorkingDirectory = "${cfg.dataDir}"; # The service creates 'commitmentlist' in the working dir
        User = "${cfg.user}";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };
  }

  (mkIf cfg.yieldgenerator.enable {
    nix-bitcoin.secrets.jm-wallet-password.user = cfg.user;

    systemd.services.joinmarket-yieldgenerator = let
      ygDefault = "${pkgs.nix-bitcoin.joinmarket}/bin/jm-yg-privacyenhanced";
      ygBinary = if cfg.yieldgenerator.customParameters == "" then
        ygDefault
      else
        pkgs.runCommand "jm-yieldgenerator-custom" {
          inherit (cfg.yieldgenerator) customParameters;
        } ''
          substitute ${ygDefault} $out \
            --replace "# end of settings customization" "$customParameters"
          chmod +x $out
        '';
    in {
      description = "CoinJoin maker bot to gain privacy and passively generate income";
      wantedBy = [ "joinmarket.service" ];
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" ];
      preStart = let
        start = ''
          exec ${ygBinary} --datadir='${cfg.dataDir}' --wallet-password-stdin wallet.jmdat
        '';
      in ''
        pw=$(cat "${secretsDir}"/jm-wallet-password)
        echo "echo -n $pw | ${start}" > $RUNTIME_DIRECTORY/start
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // rec {
        RuntimeDirectory = "joinmarket-yieldgenerator"; # Only used to create start script
        RuntimeDirectoryMode = "700";
        WorkingDirectory = "${cfg.dataDir}"; # The service creates dir 'logs' in the working dir
        ExecStart = "${pkgs.bash}/bin/bash /run/${RuntimeDirectory}/start";
        User = "${cfg.user}";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };
  })
  ]);
}
