{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nix-bitcoin;
  electrs-cfg = config.services.electrs;
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
    networking.firewall.allowedTCPPorts = [ ]
      ++ optionals (electrs-cfg.enable && electrs-cfg.expose-clearnet-nginxport) [ electrs-cfg.nginxport ];

    # Tor
    services.tor.enable = true;
    services.tor.client.enable = true;

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
    services.bitcoind.sysperms = if electrs-cfg.enable then true else null;
    services.bitcoind.disablewallet = if electrs-cfg.enable then true else null;
    services.bitcoind.proxy = config.services.tor.client.socksListenAddress;
    services.bitcoind.port = 8333;
    services.bitcoind.rpcuser = "bitcoinrpc";
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
    services.clightning.always-use-proxy = true;
    services.clightning.bind-addr = "127.0.0.1:9735";
    services.tor.hiddenServices.clightning = {
      map = [{
        port = 9735; toPort = 9735;
      }];
      version = 3;
    };

    # Create user operator which can use bitcoin-cli and lightning-cli
    users.users.operator = {
      isNormalUser = true;
      extraGroups = [ config.services.bitcoind.group ]
        ++ (if config.services.clightning.enable then [ "clightning" ] else [ ])
        ++ (if config.services.liquidd.enable then [ config.services.liquidd.group ] else [ ])
        ++ (if (config.services.hardware-wallets.ledger || config.services.hardware-wallets.trezor)
          then [ config.services.hardware-wallets.group ] else [ ]);
    };
    # Give operator access to onion hostnames
    services.onion-chef.enable = true;
    services.onion-chef.access.operator = [ "bitcoind" "clightning" "nginx" "liquidd" "spark-wallet" "electrs" "sshd" ];

    environment.interactiveShellInit = ''
      alias bitcoin-cli='bitcoin-cli -datadir=${config.services.bitcoind.dataDir}'
      alias lightning-cli='sudo -u clightning lightning-cli --lightning-dir=${config.services.clightning.dataDir}'
    '' + (if config.services.liquidd.enable then ''
      alias elements-cli='elements-cli -datadir=${config.services.liquidd.dataDir}'
    '' else "");
    # Unfortunately c-lightning doesn't allow setting the permissions of the rpc socket
    # https://github.com/ElementsProject/lightning/issues/1366
    security.sudo.configFile = (
      if config.services.clightning.enable then ''
        operator    ALL=(clightning) NOPASSWD: ALL
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
    services.liquidd.port = 7042;
    services.tor.hiddenServices.liquidd = {
      map = [{
        port = config.services.liquidd.port; toPort = config.services.liquidd.port;
      }];
      version = 3;
    };

    services.spark-wallet.onion-service = true;

    services.tor.hiddenServices.electrs = {
      map = [{
        port = electrs-cfg.onionport; toPort = electrs-cfg.nginxport;
      }];
      version = 3;
    };
    environment.systemPackages = with pkgs; [
      tor
      altcoins.bitcoind
      nodeinfo
      banlist
      jq
      qrencode
    ]
    ++ optionals config.services.clightning.enable [clightning]
    ++ optionals config.services.lightning-charge.enable [lightning-charge]
    ++ optionals config.services.nanopos.enable [nanopos]
    ++ optionals config.services.nix-bitcoin-webindex.enable [nginx]
    ++ optionals config.services.liquidd.enable [elementsd]
    ++ optionals config.services.spark-wallet.enable [spark-wallet]
    ++ optionals electrs-cfg.enable [electrs]
    ++ optionals (config.services.hardware-wallets.ledger || config.services.hardware-wallets.trezor) [
        hwi
        # To allow debugging issues with lsusb:
        usbutils
    ]
    ++ optionals config.services.hardware-wallets.trezor [
        python35.pkgs.trezor
    ];
  };
}

