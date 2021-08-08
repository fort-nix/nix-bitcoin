{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.joinmarket;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  inherit (config.services) bitcoind;
  torAddress = builtins.head (builtins.split ":" config.services.tor.client.socksListenAddress);
  # Based on https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/jmclient/jmclient/configure.py
  yg = cfg.yieldgenerator;
  configFile = builtins.toFile "config" ''
    [DAEMON]
    no_daemon = 0
    daemon_port = 27183
    daemon_host = localhost
    use_ssl = false

    [BLOCKCHAIN]
    blockchain_source = bitcoin-rpc
    network = ${bitcoind.network}
    rpc_host = ${bitcoind.rpc.address}
    rpc_port = ${toString bitcoind.rpc.port}
    rpc_user = ${bitcoind.rpc.users.privileged.name}
    @@RPC_PASSWORD@@
    ${optionalString (cfg.rpcWalletFile != null) "rpc_wallet_file=${cfg.rpcWalletFile}"}

    [MESSAGING:server1]
    host = darkirc6tqgpnwd3blln3yfv5ckl47eg7llfxkmtovrv7c7iwohhb6ad.onion
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
    native = true
    merge_algorithm = default
    tx_fees = 3
    absurd_fee_per_kb = 350000
    max_sweep_fee_change = 0.8
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

    [YIELDGENERATOR]
    ordertype = ${yg.ordertype}
    cjfee_a = ${toString yg.cjfee_a}
    cjfee_r = ${toString yg.cjfee_r}
    cjfee_factor = ${toString yg.cjfee_factor}
    txfee = ${toString yg.txfee}
    txfee_factor = ${toString yg.txfee_factor}
    minsize = ${toString yg.minsize}
    size_factor = ${toString yg.size_factor}
    gaplimit = 6

    [SNICKER]
    enabled = false
    lowest_net_gain = 0
    servers = cn5lfwvrswicuxn3gjsxoved6l2gu5hdvwy5l3ev7kg6j7lbji2k7hqd.onion,
    polling_interval_minutes = 60
  '';

   # The jm scripts create a 'logs' dir in the working dir,
   # so run them inside dataDir.
   cli = pkgs.runCommand "joinmarket-cli" {} ''
     mkdir -p $out/bin
     jm=${nbPkgs.joinmarket}/bin
     cd $jm
     for bin in jm-*; do
       {
         echo "#!${pkgs.bash}/bin/bash";
         echo "cd '${cfg.dataDir}' && ${cfg.cliExec} ${runAsUser} ${cfg.user} $jm/$bin --datadir='${cfg.dataDir}' \"\$@\"";
       } > $out/bin/$bin
     done
     chmod -R +x $out/bin
   '';
in {
  options.services.joinmarket = {
    enable = mkEnableOption "JoinMarket";
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
    rpcWalletFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the watch-only bitcoind wallet the JoinMarket addresses are imported to.
      '';
    };
    cli = mkOption {
      default = cli;
    };
    # This option is only used by netns-isolation
    enforceTor = mkOption {
      readOnly = true;
      default = true;
    };
    inherit (nbLib) cliExec;

    yieldgenerator = {
      enable = mkEnableOption "yield generator bot";
      ordertype = mkOption {
        type = types.enum [ "reloffer" "absoffer" ];
        default = "reloffer";
        description = ''
          Which fee type to actually use
        '';
      };
      cjfee_a = mkOption {
        type = types.ints.unsigned;
        default = 500;
        description = ''
          Absolute offer fee you wish to receive for coinjoins (cj) in Satoshis
        '';
      };
      cjfee_r = mkOption {
        type = types.float;
        default = 0.00002;
        description = ''
          Relative offer fee you wish to receive based on a cj's amount
        '';
      };
      cjfee_factor = mkOption {
        type = types.float;
        default = 0.1;
        description = ''
          Variance around the average cj fee
        '';
      };
      txfee = mkOption {
        type = types.ints.unsigned;
        default = 100;
        description = ''
          The average transaction fee you're adding to coinjoin transactions
        '';
      };
      txfee_factor = mkOption {
        type = types.float;
        default = 0.3;
        description = ''
          Variance around the average tx fee
        '';
      };
      minsize = mkOption {
        type = types.ints.unsigned;
        default = 100000;
        description = ''
          Minimum size of your cj offer in Satoshis. Lower cj amounts will be disregarded.
        '';
      };
      size_factor = mkOption {
        type = types.float;
        default = 0.1;
        description = ''
          Variance around all offer sizes
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [{
    services.bitcoind = {
      enable = true;
      disablewallet = false;
    };

    # Joinmarket is Tor-only
    services.tor = {
      enable = true;
      client.enable = true;
      # Needed for payjoin onion service creation
      controlSocket.enable = true;
    };

    environment.systemPackages = [
      (hiPrio cfg.cli)
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.joinmarket = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStartPre = nbLib.script "joinmarket-create-config" ''
          install -o '${cfg.user}' -g '${cfg.group}' -m 640 ${configFile} ${cfg.dataDir}/joinmarket.cfg
          sed -i \
             "s|@@RPC_PASSWORD@@|rpc_password = $(cat ${secretsDir}/bitcoin-rpcpassword-privileged)|" \
             '${cfg.dataDir}/joinmarket.cfg'
        '';
        # Generating wallets (jmclient/wallet.py) is only supported for mainnet or testnet
        ExecStartPost = mkIf (bitcoind.network == "mainnet")
          (nbLib.script "joinmarket-create-wallet" ''
            walletname=wallet.jmdat
            wallet=${cfg.dataDir}/wallets/$walletname
            if [[ ! -f $wallet ]]; then
              echo "Create wallet"
              pw=$(cat "${secretsDir}"/jm-wallet-password)
              cd ${cfg.dataDir}
              if ! ${nbPkgs.joinmarket}/bin/jm-genwallet --datadir=${cfg.dataDir} $walletname $pw \
                     | grep 'recovery_seed' \
                     | cut -d ':' -f2 \
                     | (umask u=r,go=; cat > jm-wallet-seed); then
                echo "wallet creation failed"
                rm -f "$wallet" jm-wallet-seed
                exit 1
              fi
            fi
          '');
        ExecStart = "${nbPkgs.joinmarket}/bin/joinmarketd";
        WorkingDirectory = cfg.dataDir; # The service creates 'commitmentlist' in the working dir
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowTor;
    };

    users.users.${cfg.user} = {
      group = cfg.group;
      home = cfg.dataDir;
      # Allow access to the tor control socket, needed for payjoin onion service creation
      extraGroups = [ "tor" "bitcoin" ];
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      allowRunAsUsers = [ cfg.group ];
    };

    nix-bitcoin.secrets.jm-wallet-password.user = cfg.user;
  }

  (mkIf cfg.yieldgenerator.enable {
    systemd.services.joinmarket-yieldgenerator = {
      wantedBy = [ "joinmarket.service" ];
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" ];
      preStart = let
        start = ''
          exec ${nbPkgs.joinmarket}/bin/jm-yg-privacyenhanced --datadir='${cfg.dataDir}' --wallet-password-stdin wallet.jmdat
        '';
      in ''
        pw=$(cat "${secretsDir}"/jm-wallet-password)
        echo "echo -n $pw | ${start}" > $RUNTIME_DIRECTORY/start
      '';
      serviceConfig = nbLib.defaultHardening // rec {
        RuntimeDirectory = "joinmarket-yieldgenerator"; # Only used to create start script
        RuntimeDirectoryMode = "700";
        WorkingDirectory = cfg.dataDir; # The service creates dir 'logs' in the working dir
        ExecStart = "${pkgs.bash}/bin/bash /run/${RuntimeDirectory}/start";
        # Show "joinmarket-yieldgenerator" instead of "bash" in the journal.
        # The parent bash start process has to run alongside the main process
        # because it provides the wallet password via stdin to the main process
        SyslogIdentifier = "joinmarket-yieldgenerator";
        User = cfg.user;
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowTor;
    };
  })
  ]);
}
