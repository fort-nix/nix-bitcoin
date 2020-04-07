{ config, lib, pkgs, ... }:

with lib;

let
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

  config =  {
    # For backwards compatibility only
    nix-bitcoin.secretsDir = mkDefault "/secrets";

    networking.firewall.enable = true;

    # Tor
    services.tor = {
      enable = true;
      client.enable = true;
      # LND uses ControlPort to create onion services
      controlPort = mkIf config.services.lnd.enable 9051;

      hiddenServices.sshd = mkHiddenService { port = 22; };
    };

    # bitcoind
    services.bitcoind = {
      enable = true;
      listen = true;
      sysperms = if config.services.electrs.enable then true else null;
      disablewallet = if config.services.electrs.enable then true else null;
      proxy = config.services.tor.client.socksListenAddress;
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
    services.tor.hiddenServices.bitcoind = mkHiddenService { port = config.services.bitcoind.port; };

    # clightning
    services.clightning = {
      bitcoin-rpcuser = config.services.bitcoind.rpcuser;
      proxy = config.services.tor.client.socksListenAddress;
      enforceTor = true;
      always-use-proxy = true;
      bind-addr = "127.0.0.1:9735";
    };
    services.tor.hiddenServices.clightning = mkHiddenService { port = 9735; };

    # lnd
    services.lnd.enforceTor = true;

    # liquidd
    services.liquidd = {
      rpcuser = "liquidrpc";
      prune = 1000;
      extraConfig = "
      mainchainrpcuser=${config.services.bitcoind.rpcuser}
      mainchainrpcport=8332
    ";
      validatepegin = true;
      listen = true;
      proxy = config.services.tor.client.socksListenAddress;
      enforceTor = true;
      port = 7042;
    };
    services.tor.hiddenServices.liquidd = mkHiddenService { port = config.services.liquidd.port; };

    # electrs
    services.electrs = {
      port = 50001;
      enforceTor = true;
      onionport = 50002;
      TLSProxy.enable = true;
      TLSProxy.port = 50003;
    };
    services.tor.hiddenServices.electrs = mkHiddenService {
      port = config.services.electrs.onionport;
      toPort = config.services.electrs.TLSProxy.port;
    };

    services.spark-wallet.onion-service = true;

    services.nix-bitcoin-webindex.enforceTor = true;


    environment.systemPackages = with pkgs; with nix-bitcoin; let
      s = config.services;
    in
    [
      tor
      bitcoind
      (hiPrio s.bitcoind.cli)
      nodeinfo
      jq
      qrencode
    ]
    ++ optionals s.clightning.enable [clightning (hiPrio s.clightning.cli)]
    ++ optionals s.lnd.enable [lnd (hiPrio s.lnd.cli)]
    ++ optionals s.lightning-charge.enable [lightning-charge]
    ++ optionals s.nanopos.enable [nanopos]
    ++ optionals s.nix-bitcoin-webindex.enable [nginx]
    ++ optionals s.liquidd.enable [elementsd (hiPrio s.liquidd.cli) (hiPrio s.liquidd.swap-cli)]
    ++ optionals s.spark-wallet.enable [spark-wallet]
    ++ optionals s.electrs.enable [electrs]
    ++ optionals (s.hardware-wallets.ledger || s.hardware-wallets.trezor) [
        hwi
        # To allow debugging issues with lsusb
        usbutils
    ]
    ++ optionals s.hardware-wallets.trezor [
        python3.pkgs.trezor
    ];

    # Create user operator which can use bitcoin-cli and lightning-cli
    users.users.operator = {
      isNormalUser = true;
      extraGroups = [ config.services.bitcoind.group ]
        ++ (if config.services.clightning.enable then [ "clightning" ] else [ ])
        ++ (if config.services.lnd.enable then [ "lnd" ] else [ ])
        ++ (if config.services.liquidd.enable then [ config.services.liquidd.group ] else [ ])
        ++ (if (config.services.hardware-wallets.ledger || config.services.hardware-wallets.trezor)
          then [ config.services.hardware-wallets.group ] else [ ]);
    };
    # Give operator access to onion hostnames
    services.onion-chef.enable = true;
    services.onion-chef.access.operator = [ "bitcoind" "clightning" "nginx" "liquidd" "spark-wallet" "electrs" "sshd" ];

    # Unfortunately c-lightning doesn't allow setting the permissions of the rpc socket
    # https://github.com/ElementsProject/lightning/issues/1366
    security.sudo.configFile =
     (optionalString config.services.clightning.enable ''
       operator    ALL=(clightning) NOPASSWD: ALL
     '') +
     (optionalString config.services.lnd.enable ''
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
