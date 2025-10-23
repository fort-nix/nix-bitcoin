{ config, lib, pkgs, ... }:

with lib;
let
  options.services.joinmarket = {
    enable = mkEnableOption "JoinMarket, a Bitcoin CoinJoin implementation";
    payjoinAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The address where payjoin onion connections are forwarded to.
        This address is never used directly, it only serves as the internal endpoint
        for the payjoin onion service.
        The onion service is automatically setup by joinmarket and accepts
        connections at port 80.
      '';
    };
    payjoinPort = mkOption {
      type = types.port;
      default = 64180; # A random private port
      description = "The port corresponding to option {option}`payjoinAddress`.";
    };
    messagingAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The address where messaging onion connections are forwarded to.
        This address is never used directly, it only serves as the internal endpoint
        for the messaging onion service.
        The onion service is automatically setup by joinmarket.
      '';
    };
    messagingPort = mkOption {
      type = types.port;
      default = 64181; # payjoinPort + 1
      description = "The port corresponding to option {option}`messagingAddress`.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/joinmarket";
      description = "The data directory for JoinMarket.";
    };
    rpcWalletFile = mkOption {
      type = types.nullOr types.nonEmptyStr;
      default = "jm_wallet";
      description = ''
        Name of the watch-only bitcoind wallet the JoinMarket addresses are imported to.
      '';
    };
    settings = mkOption {
      type = with types; attrsOf anything;
      example = {
        POLICY = {
          merge_algorithm = "gradual";
          tx_fees = 5;
        };
        LOGGING = {
          console_log_level = "DEBUG";
        };
      };
      description = ''
        Joinmarket settings.
        See here for possible options:
        https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/src/jmclient/configure.py#:~:text=defaultconfig%20=
        If your web browser does not support text fragment URLs, you can can manually
        search for string `defaultconfig =` to jump to the correct location.
      '';
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
      defaultText = "(See source)";
    };
    # This option is only used by netns-isolation.
    # Tor is always enabled.
    tor.enforce = nbLib.tor.enforce;
    inherit (nbLib) cliExec;

    yieldgenerator = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the JoinMarket yield generator bot.
          Documentation: https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/YIELDGENERATOR.md
        '';
      };
      ordertype = mkOption {
        type = types.enum [ "reloffer" "absoffer" ];
        default = "reloffer";
        description = ''
          Which fee type to actually use.
        '';
      };
      cjfee_a = mkOption {
        type = types.ints.unsigned;
        default = 500;
        description = ''
          Absolute offer fee you wish to receive for coinjoins (cj) in Satoshis.
        '';
      };
      cjfee_r = mkOption {
        type = types.float;
        default = 0.00002;
        description = ''
          Relative offer fee you wish to receive based on a cj's amount.
        '';
      };
      cjfee_factor = mkOption {
        type = types.float;
        default = 0.1;
        description = ''
          Variance around the average cj fee.
        '';
      };
      txfee_contribution_factor = mkOption {
        type = types.float;
        default = 0.3;
        description = ''
          Variance around the average tx fee.
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
          Variance around all offer sizes.
        '';
      };
    };
  };

  cfg = config.services.joinmarket;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  inherit (config.services) bitcoind;

  torAddress = config.services.tor.client.socksListenAddress;

  socks5Settings = {
    socks5 = true;
    socks5_host = torAddress.addr;
    socks5_port = torAddress.port;
  };

   # The jm scripts create a 'logs' dir in the working dir,
   # so run them inside dataDir.
   cli = pkgs.runCommand "joinmarket-cli" {} ''
     mkdir -p "$out/bin"
     jm=${nbPkgs.joinmarket}/bin
     cd "$jm"
     for bin in jm-*; do
       {
         echo "#!${pkgs.bash}/bin/bash";
         echo "cd '${cfg.dataDir}' && ${cfg.cliExec} ${runAsUser} ${cfg.user} "$jm/$bin" --datadir='${cfg.dataDir}' \"\$@\"";
       } > "$out/bin/$bin"
     done
     chmod -R +x "$out/bin"
   '';
in {
  inherit options;

  config = mkMerge [
  {
    services.joinmarket.settings = {
      DAEMON = {
        no_daemon = 0;
        daemon_port = 27183;
        daemon_host = "127.0.0.1";
      };
      BLOCKCHAIN = {
        blockchain_source = bitcoind.makeNetworkName "bitcoin-rpc" "regtest";
        network = bitcoind.makeNetworkName "mainnet" "testnet";
        rpc_host = nbLib.address bitcoind.rpc.address;
        rpc_port = bitcoind.rpc.port;
        rpc_user = bitcoind.rpc.users.privileged.name;
        rpc_wallet_file = if cfg.rpcWalletFile == null then "" else cfg.rpcWalletFile;
      };
      LOGGING = {
        color = false;
      };
      PAYJOIN = {
        onion_socks5_host = torAddress.addr;
        onion_socks5_port = torAddress.port;
        tor_control_host = "unix:/run/tor/control";
        onion_serving_host = cfg.payjoinAddress;
        onion_serving_port = cfg.payjoinPort;
        hidden_service_ssl = false;
      };
      YIELDGENERATOR = removeAttrs cfg.yieldgenerator [
        "enable"
        # TODO: This is only needed when ./obsolete-options.nix is imported
        "txfee"
      ];

      # Messaging settings have to be fully specified because joinmarket doesn't
      # provide default messaging settings.
      # (`jmclient/configure.py` actually does contain default messaging settings, but
      # they are removed via fn `_remove_unwanted_default_settings`)
      "MESSAGING:onion" = socks5Settings // {
        type = "onion";
        tor_control_host = "unix:/run/tor/control";
        # Required option, but ignored because `tor_control_host` is a unix socket
        tor_control_port = 9051;
        onion_serving_host = cfg.messagingAddress;
        onion_serving_port = cfg.messagingPort;
        hidden_service_dir = "";
        directory_nodes = "g3hv4uynnmynqqq2mchf3fcm3yd46kfzmcdogejuckgwknwyq5ya6iad.onion:5222,3kxw6lf5vf6y26emzwgibzhrzhmhqiw6ekrek3nqfjjmhwznb2moonad.onion:5222,bqlpq6ak24mwvuixixitift4yu42nxchlilrcqwk2ugn45tdclg42qid.onion:5222";
      };
      # irc.darkscience.net
      "MESSAGING:server1" = socks5Settings // {
        host = "darkirc6tqgpnwd3blln3yfv5ckl47eg7llfxkmtovrv7c7iwohhb6ad.onion";
        channel = "joinmarket-pit";
        port = 6697;
        usessl = true;
      };
      # ilita
      "MESSAGING:server2" = socks5Settings // {
        host = "ilitafrzzgxymv6umx2ux7kbz3imyeko6cnqkvy4nisjjj4qpqkrptid.onion";
        channel = "joinmarket-pit";
        port = 6667;
        usessl = false;
      };
      # irc.hackint.org
      "MESSAGING:server3" = socks5Settings // {
        host = "ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion";
        channel = "joinmarket-pit";
        port = 6667;
        usessl = false;
      };
    };
  }

  (mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionOlder bitcoind.package.version "30";
        message = ''
          Joinmarket is not compatible with bitcoind >= 30.
          (https://github.com/JoinMarket-Org/joinmarket-clientserver/pull/1775)

          To fix this, add the following to your config:
          services.bitcoind.package = config.nix-bitcoin.pkgs.bitcoind_29;
        '';
      }
    ];

    services.bitcoind = {
      enable = true;
      disablewallet = false;
      # TODO-EXTERNAL: remove when joinmarket supports descriptor wallets
      # (https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/1571).
      extraConfig = ''
        deprecatedrpc=create_bdb
      '';
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
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      preStart = ''
        {
          cat ${builtins.toFile "joinmarket.cfg" ((generators.toINI {}) cfg.settings)}
          echo
          echo '[BLOCKCHAIN]'
          echo "rpc_password = $(cat ${secretsDir}/bitcoin-rpcpassword-privileged)"
        } > '${cfg.dataDir}/joinmarket.cfg'
      '';
      postStart = ''
        walletname=wallet.jmdat
        wallet="${cfg.dataDir}/wallets/$walletname"
        if [[ ! -f $wallet ]]; then
          ${optionalString (cfg.rpcWalletFile != null) ''
            echo "Create watch-only wallet ${cfg.rpcWalletFile}"
            if ! output=$(${bitcoind.cli}/bin/bitcoin-cli -named createwallet \
                            wallet_name="${cfg.rpcWalletFile}" \
                            descriptors=false \
                            ${optionalString (!bitcoind.regtest) "disable_private_keys=true"} 2>&1
                         ); then
              # Ignore error if bitcoind wallet already exists
              if [[ $output != *"already exists"* ]]; then
                echo "$output"
                exit 1
              fi
            fi
          ''}

          # Restore wallet from seed if available
          seed=()
          if [[ -e jm-wallet-seed ]]; then
            seed=(--recovery-seed-file jm-wallet-seed)
          fi
          cd "${cfg.dataDir}"

          # Strip trailing newline from password file
          if ! tr -d '\n' < '${secretsDir}/jm-wallet-password' \
               | ${nbPkgs.joinmarket}/bin/jm-genwallet \
                   --datadir="${cfg.dataDir}" --wallet-password-stdin "''${seed[@]}" "$walletname" \
               | (if ((! ''${#seed[@]})); then
                    umask u=r,go=
                    grep -ohP '(?<=recovery_seed:).*' > jm-wallet-seed
                  else
                    cat > /dev/null
                  fi); then
            echo "wallet creation failed"
            rm -f "$wallet" jm-wallet-seed
            exit 1
          fi
        fi
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${nbPkgs.joinmarket}/bin/joinmarketd";
        WorkingDirectory = cfg.dataDir; # The service creates 'commitmentlist' in the working dir
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      # Allow access to the tor control socket, needed for payjoin onion service creation
      extraGroups = [ "tor" "bitcoin" ];
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      allowRunAsUsers = [ cfg.user ];
    };

    nix-bitcoin.secrets.jm-wallet-password.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.joinmarket = ''
      makePasswordSecret jm-wallet-password
    '';
  })

  (mkIf (cfg.enable && cfg.yieldgenerator.enable) {
    systemd.services.joinmarket-yieldgenerator = {
      wantedBy = [ "joinmarket.service" ];
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" "nix-bitcoin-secrets.target" ];
      script = ''
        tr -d "\n" <"${secretsDir}/jm-wallet-password" \
        | ${nbPkgs.joinmarket}/bin/jm-yg-privacyenhanced --datadir='${cfg.dataDir}' \
          --wallet-password-stdin wallet.jmdat
      '';
      serviceConfig = nbLib.defaultHardening // rec {
        WorkingDirectory = cfg.dataDir; # The service creates dir 'logs' in the working dir
        # Show "joinmarket-yieldgenerator" instead of "bash" in the journal.
        # The start script has to run alongside the main process
        # because it provides the wallet password via stdin to the main process
        SyslogIdentifier = "joinmarket-yieldgenerator";
        User = cfg.user;
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowTor;
    };
  })
  ];
}
