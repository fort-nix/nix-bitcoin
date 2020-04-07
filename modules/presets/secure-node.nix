{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;

  mkHiddenService = map: {
    map = [ map ];
    version = 3;
  };

  operatorCopySSH = pkgs.writeText "operator-copy-ssh.sh" ''
    mkdir -p ${config.users.users.operator.home}/.ssh
    if [ -e "${config.users.users.root.home}/.vbox-nixops-client-key" ]; then
      cp ${config.users.users.root.home}/.vbox-nixops-client-key ${config.users.users.operator.home}/.ssh/authorized_keys
    fi
    if [ -e "/etc/ssh/authorized_keys.d/root" ]; then
      cat /etc/ssh/authorized_keys.d/root >> ${config.users.users.operator.home}/.ssh/authorized_keys
    fi
    chown -R operator ${config.users.users.operator.home}/.ssh
  '';
in {
  imports = [ ../modules.nix ];

  options = {
    services.clightning.onionport = mkOption {
      type = types.ints.u16;
      default = 9735;
      description = "Port on which to listen for tor client connections.";
    };

    services.electrs.onionport = mkOption {
      type = types.ints.u16;
      default = 50002;
      description = "Port on which to listen for tor client connections.";
    };
  };

  config =  {
    # For backwards compatibility only
    nix-bitcoin.secretsDir = mkDefault "/secrets";

    networking.firewall.enable = true;

    # Tor
    services.tor = {
      enable = true;
      client.enable = true;
      # LND uses ControlPort to create onion services
      controlPort = mkIf cfg.lnd.enable 9051;

      hiddenServices.sshd = mkHiddenService { port = 22; };
    };

    # bitcoind
    services.bitcoind = {
      enable = true;
      listen = true;
      sysperms = if cfg.electrs.enable then true else null;
      disablewallet = if cfg.electrs.enable then true else null;
      proxy = cfg.tor.client.socksListenAddress;
      enforceTor = true;
      port = 8333;
      zmqpubrawblock = "tcp://127.0.0.1:28332";
      zmqpubrawtx = "tcp://127.0.0.1:28333";
      assumevalid = "00000000000000000000e5abc3a74fe27dc0ead9c70ea1deb456f11c15fd7bc6";
      addnodes = [ "ecoc5q34tmbq54wl.onion" ];
      discover = false;
      addresstype = "bech32";
      prune = 0;
      dbCache = 1000;
    };
    services.tor.hiddenServices.bitcoind = mkHiddenService { port = cfg.bitcoind.port; };

    # clightning
    services.clightning = {
      bitcoin-rpcuser = cfg.bitcoind.rpcuser;
      proxy = cfg.tor.client.socksListenAddress;
      enforceTor = true;
      always-use-proxy = true;
      bind-addr = "127.0.0.1:${toString cfg.clightning.onionport}";
    };
    services.tor.hiddenServices.clightning = mkHiddenService { port = cfg.clightning.onionport; };

    # lnd
    services.lnd.enforceTor = true;

    # liquidd
    services.liquidd = {
      rpcuser = "liquidrpc";
      prune = 1000;
      extraConfig = "
      mainchainrpcuser=${cfg.bitcoind.rpcuser}
      mainchainrpcport=8332
    ";
      validatepegin = true;
      listen = true;
      proxy = cfg.tor.client.socksListenAddress;
      enforceTor = true;
      port = 7042;
    };
    services.tor.hiddenServices.liquidd = mkHiddenService { port = cfg.liquidd.port; };

    # electrs
    services.electrs = {
      port = 50001;
      enforceTor = true;
      TLSProxy.enable = true;
      TLSProxy.port = 50003;
    };
    services.tor.hiddenServices.electrs = mkHiddenService {
      port = cfg.electrs.onionport;
      toPort = cfg.electrs.TLSProxy.port;
    };

    services.spark-wallet.onion-service = true;

    services.nix-bitcoin-webindex.enforceTor = true;


    environment.systemPackages = with pkgs; with nix-bitcoin;
    [
      tor
      bitcoind
      (hiPrio cfg.bitcoind.cli)
      nodeinfo
      jq
      qrencode
    ]
    ++ optionals cfg.clightning.enable [clightning (hiPrio cfg.clightning.cli)]
    ++ optionals cfg.lnd.enable [lnd (hiPrio cfg.lnd.cli)]
    ++ optionals cfg.lightning-charge.enable [lightning-charge]
    ++ optionals cfg.nanopos.enable [nanopos]
    ++ optionals cfg.nix-bitcoin-webindex.enable [nginx]
    ++ optionals cfg.liquidd.enable [elementsd (hiPrio cfg.liquidd.cli) (hiPrio cfg.liquidd.swap-cli)]
    ++ optionals cfg.spark-wallet.enable [spark-wallet]
    ++ optionals cfg.electrs.enable [electrs]
    ++ optionals (cfg.hardware-wallets.ledger || cfg.hardware-wallets.trezor) [
        hwi
        # To allow debugging issues with lsusb
        usbutils
    ]
    ++ optionals cfg.hardware-wallets.trezor [
        python3.pkgs.trezor
    ];

    # Create user operator which can use bitcoin-cli and lightning-cli
    users.users.operator = {
      isNormalUser = true;
      extraGroups = [ cfg.bitcoind.group ]
        ++ (optionals cfg.clightning.enable [ "clightning" ])
        ++ (optionals cfg.lnd.enable [ "lnd" ])
        ++ (optionals cfg.liquidd.enable [ cfg.liquidd.group ])
        ++ (optionals (cfg.hardware-wallets.ledger || cfg.hardware-wallets.trezor)
            [ cfg.hardware-wallets.group ]);
    };
    # Give operator access to onion hostnames
    services.onion-chef.enable = true;
    services.onion-chef.access.operator = [ "bitcoind" "clightning" "nginx" "liquidd" "spark-wallet" "electrs" "sshd" ];

    # Unfortunately c-lightning doesn't allow setting the permissions of the rpc socket
    # https://github.com/ElementsProject/lightning/issues/1366
    security.sudo.configFile =
     (optionalString cfg.clightning.enable ''
       operator    ALL=(clightning) NOPASSWD: ALL
     '') +
     (optionalString cfg.lnd.enable ''
       operator    ALL=(lnd) NOPASSWD: ALL
     '');

    # Give root ssh access to the operator account
    systemd.services.copy-root-authorized-keys = {
      description = "Copy root authorized keys";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash \"${operatorCopySSH}\"";
        user = "root";
        type = "oneshot";
      };
    };
  };
}
