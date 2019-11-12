{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nix-bitcoin;
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
  imports = [
    ./nix-bitcoin-pkgs.nix
    ./bitcoind.nix
    ./clightning.nix
    ./lightning-charge.nix
    ./nanopos.nix
    ./nix-bitcoin-webindex.nix
    ./liquid.nix
    ./spark-wallet.nix
    ./electrs.nix
    ./onion-chef.nix
    ./recurring-donations.nix
    ./hardware-wallets.nix
    ./lnd.nix
  ];

  options.services.nix-bitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nix-bitcoin service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.enable = true;

    # Tor
    services.tor.enable = true;
    services.tor.client.enable = true;
    # LND uses ControlPort to create onion services
    services.tor.controlPort = if config.services.lnd.enable then 9051 else null;

    # Tor SSH service
    services.tor.hiddenServices.sshd = {
      map = [{
        port = 22;
      }];
      version = 3;
    };

    # bitcoind
    services.bitcoind.enable = true;
    services.bitcoind.listen = true;
    services.bitcoind.sysperms = if config.services.electrs.enable then true else null;
    services.bitcoind.disablewallet = if config.services.electrs.enable then true else null;
    services.bitcoind.proxy = config.services.tor.client.socksListenAddress;
    services.bitcoind.enforceTor = true;
    services.bitcoind.port = 8333;
    services.bitcoind.rpcuser = "bitcoinrpc";
    services.bitcoind.zmqpubrawblock = "tcp://127.0.0.1:28332";
    services.bitcoind.zmqpubrawtx = "tcp://127.0.0.1:28333";
    services.bitcoind.extraConfig = ''
      assumevalid=0000000000000000000726d186d6298b5054b9a5c49639752294b322a305d240
      addnode=ecoc5q34tmbq54wl.onion
      discover=0
      addresstype=bech32
      changetype=bech32
    '';
    services.bitcoind.prune = 0;
    services.bitcoind.dbCache = 1000;
    services.tor.hiddenServices.bitcoind = {
      map = [{
        port = config.services.bitcoind.port;
      }];
      version = 3;
    };

    # Add bitcoinrpc group
    users.groups.bitcoinrpc = {};

    # clightning
    services.clightning.bitcoin-rpcuser = config.services.bitcoind.rpcuser;
    services.clightning.proxy = config.services.tor.client.socksListenAddress;
    services.clightning.enforceTor = true;
    services.clightning.always-use-proxy = true;
    services.clightning.bind-addr = "127.0.0.1:9735";
    services.tor.hiddenServices.clightning = {
      map = [{
        port = 9735; toPort = 9735;
      }];
      version = 3;
    };

    # lnd
    services.lnd.enforceTor = true;

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

    environment.interactiveShellInit = ''
      ${optionalString (config.services.clightning.enable) ''
        alias lightning-cli='sudo -u clightning lightning-cli --lightning-dir=${config.services.clightning.dataDir}'
      ''}
      ${optionalString (config.services.lnd.enable) ''
        alias lncli='sudo -u lnd lncli --tlscertpath /secrets/lnd_cert --macaroonpath ${config.services.lnd.dataDir}/chain/bitcoin/mainnet/admin.macaroon'
      ''}
      ${optionalString (config.services.liquidd.enable) ''
        alias elements-cli='elements-cli -datadir=${config.services.liquidd.dataDir}'
        alias liquidswap-cli='liquidswap-cli -c ${config.services.liquidd.dataDir}/elements.conf'
      ''}
    '';
    # Unfortunately c-lightning doesn't allow setting the permissions of the rpc socket
    # https://github.com/ElementsProject/lightning/issues/1366
    security.sudo.configFile = (
      if config.services.clightning.enable then ''
        operator    ALL=(clightning) NOPASSWD: ALL
      ''
      else if config.services.lnd.enable then ''
        operator    ALL=(lnd) NOPASSWD: ALL
      ''
      else ""
    );

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

    services.nix-bitcoin-webindex.enforceTor = true;

    services.liquidd.rpcuser = "liquidrpc";
    services.liquidd.prune = 1000;
    services.liquidd.extraConfig = "
      mainchainrpcuser=${config.services.bitcoind.rpcuser}
      mainchainrpcport=8332
    ";
    services.liquidd.validatepegin = true;
    services.liquidd.listen = true;
    services.liquidd.proxy = config.services.tor.client.socksListenAddress;
    services.liquidd.enforceTor = true;
    services.liquidd.port = 7042;
    services.tor.hiddenServices.liquidd = {
      map = [{
        port = config.services.liquidd.port; toPort = config.services.liquidd.port;
      }];
      version = 3;
    };

    services.spark-wallet.onion-service = true;
    services.electrs.port = 50001;
    services.electrs.enforceTor = true;
    services.electrs.onionport = 50002;
    services.electrs.nginxport = 50003;
    services.tor.hiddenServices.electrs = {
      map = [{
        port = config.services.electrs.onionport; toPort = config.services.electrs.nginxport;
      }];
      version = 3;
    };
    environment.systemPackages = with pkgs; [
      tor
      blockchains.bitcoind
      (hiPrio config.services.bitcoind.cli)
      nodeinfo
      banlist
      jq
      qrencode
    ]
    ++ optionals config.services.clightning.enable [clightning]
    ++ optionals config.services.lnd.enable [lnd]
    ++ optionals config.services.lightning-charge.enable [lightning-charge]
    ++ optionals config.services.nanopos.enable [nanopos]
    ++ optionals config.services.nix-bitcoin-webindex.enable [nginx]
    ++ optionals config.services.liquidd.enable [elementsd liquid-swap]
    ++ optionals config.services.spark-wallet.enable [spark-wallet]
    ++ optionals config.services.electrs.enable [electrs]
    ++ optionals (config.services.hardware-wallets.ledger || config.services.hardware-wallets.trezor) [
        hwi
        # To allow debugging issues with lsusb:
        usbutils
    ]
    ++ optionals config.services.hardware-wallets.trezor [
        python3.pkgs.trezor
    ];
  };
}

