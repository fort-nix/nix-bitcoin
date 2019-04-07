{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nix-bitcoin;
  minimalPackages = with pkgs; [
    tor
    bitcoin
    clightning
    nodeinfo
    banlist
    jq
  ];
  allPackages = with pkgs; [
    liquidd
    lightning-charge
    nanopos
    spark-wallet
    nodejs-8_x
    nginx
  ];
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
  ];

  options.services.nix-bitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nix-bitcoin service will be installed.
      '';
    };
    modules = mkOption {
      type = types.enum [ "minimal" "all" ];
      default = "minimal";
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
    services.bitcoind.port = 8333;
    services.bitcoind.rpcuser = "bitcoinrpc";
    services.bitcoind.extraConfig = ''
      assumevalid=0000000000000000000726d186d6298b5054b9a5c49639752294b322a305d240
      addnode=ecoc5q34tmbq54wl.onion
      discover=0
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
    services.clightning = {
      enable = true;
      bitcoin-rpcuser = config.services.bitcoind.rpcuser;
    };
    services.clightning.proxy = config.services.tor.client.socksListenAddress;
    services.clightning.always-use-proxy = true;
    services.clightning.bind-addr = "127.0.0.1:9735";
    services.tor.hiddenServices.clightning = {
      map = [{
        port = 9375; toPort = 9375;
      }];
      version = 3;
    };

    # Create user operator which can use bitcoin-cli and lightning-cli
    users.users.operator = {
      isNormalUser = true;
      extraGroups = [ "clightning" config.services.bitcoind.group ]
        ++ (if config.services.liquidd.enable then [ config.services.liquidd.group ] else [ ]);
    };
    # Give operator access to onion hostnames
    services.onion-chef.enable = true;
    services.onion-chef.access.operator = [ "bitcoind" "clightning" "nginx" "liquidd" "spark-wallet" "electrs" "sshd" ];

    environment.interactiveShellInit = ''
      alias bitcoin-cli='bitcoin-cli -datadir=${config.services.bitcoind.dataDir}'
      alias lightning-cli='sudo -u clightning lightning-cli --lightning-dir=${config.services.clightning.dataDir}'
    '' + (if config.services.liquidd.enable then ''
      alias liquid-cli='liquid-cli -datadir=${config.services.liquidd.dataDir}'
    '' else "");
    # Unfortunately c-lightning doesn't allow setting the permissions of the rpc socket
    # https://github.com/ElementsProject/lightning/issues/1366
    security.sudo.configFile = ''
      operator    ALL=(clightning) NOPASSWD: ALL
    '';

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

    services.liquidd.enable = cfg.modules == "all";
    services.liquidd.rpcuser = "liquidrpc";
    services.liquidd.prune = 1000;
    services.liquidd.extraConfig = "
      mainchainrpcuser=${config.services.bitcoind.rpcuser}
      mainchainrpcport=8332
    ";
    services.liquidd.listen = true;
    services.liquidd.proxy = config.services.tor.client.socksListenAddress;
    services.liquidd.port = 7042;
    services.tor.hiddenServices.liquidd = {
      map = [{
        port = config.services.liquidd.port; toPort = config.services.liquidd.port;
      }];
      version = 3;
    };
     
    services.lightning-charge.enable = cfg.modules == "all";
    services.nanopos.enable = cfg.modules == "all";
    services.nix-bitcoin-webindex.enable = cfg.modules == "all";
    services.clightning.autolisten = cfg.modules == "all";
    services.spark-wallet.enable = cfg.modules == "all";
    services.spark-wallet.onion-service = true;
    services.electrs.enable = false;
    services.electrs.port = 50001;
    services.electrs.high-memory = false;
    services.tor.hiddenServices.electrs = {
      map = [{
        port = config.services.electrs.port; toPort = config.services.electrs.port;
      }];
      version = 3;
    };
    environment.systemPackages = if (cfg.modules == "all") then (minimalPackages ++ allPackages) else minimalPackages;
  };
}

