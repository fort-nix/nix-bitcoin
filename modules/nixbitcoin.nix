{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin;
  minimalPackages = with pkgs; [
    bitcoin
    clightning
    nodeinfo
    jq
  ];
  allPackages = with pkgs; [
    liquidd
    lightning-charge.package
    nanopos.package
    nodejs-8_x
    nginx
  ];
in {
  imports =
    [
      # Tor module from nixpkgs but with HiddenService v3
      ./tor.nix
      ./bitcoind.nix
      ./clightning.nix
      ./lightning-charge.nix
      ./nanopos.nix
      ./nixbitcoin-webindex.nix
      ./liquid.nix
    ];

  options.services.nixbitcoin = {
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
    # Tor
    services.tor.enable = true;
    services.tor.client.enable = true;

    # bitcoind
    services.bitcoind.enable = true;
    services.bitcoind.listen = true;
    services.bitcoind.proxy = config.services.tor.client.socksListenAddress;
    services.bitcoind.port = 8333;
    services.bitcoind.rpcuser = "bitcoinrpc";
    services.bitcoind.extraConfig = ''
      assumevalid=0000000000000000000726d186d6298b5054b9a5c49639752294b322a305d240
      addnode=ecoc5q34tmbq54wl.onion
      discover=0
    '';
    services.bitcoind.prune = 2000;
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
      path  = [ ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c \"mkdir -p ${config.users.users.operator.home}/.ssh && cp ${config.users.users.root.home}/.vbox-nixops-client-key ${config.users.users.operator.home}/.ssh/authorized_keys && chown -R operator ${config.users.users.operator.home}/.ssh\"";
        user = "root";
        type = "oneshot";
      };
    };

    services.liquidd.enable = cfg.modules == "all";
    services.liquidd.rpcuser = "liquidrpc";

    services.lightning-charge.enable = cfg.modules == "all";
    services.nanopos.enable = cfg.modules == "all";
    services.nixbitcoin-webindex.enable = cfg.modules == "all";
    services.clightning.autolisten = cfg.modules == "all";
    environment.systemPackages = if (cfg.modules == "all") then (minimalPackages ++ allPackages) else minimalPackages;
  };
}
