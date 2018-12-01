{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin;
in {
  imports =
    [
      ./tor.nix
      ./bitcoind.nix
      ./clightning.nix
      ./lightning-charge.nix
    ];

  options.services.nixbitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nix-bitcoin service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Add bitcoinrpc group
    users.groups.bitcoinrpc = {};

    # Tor
    services.tor.enable = true;
    services.tor.client.enable = true;
    services.tor.hiddenServices.bitcoind = {
      map = [{
        port = config.services.bitcoind.port;
      }];
      version = 3;
    };

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

    # clightning
    services.clightning.enable = true;
    services.clightning.bitcoin-rpcuser = config.services.bitcoind.rpcuser;

    services.lightning-charge.enable = true;

    # nodeinfo
    systemd.services.nodeinfo = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      after = [ "clightning.service" "tor.service" ];
      path  = [ pkgs.clightning pkgs.jq pkgs.sudo ];
      serviceConfig = {
        ExecStart="${pkgs.bash}/bin/bash ${pkgs.nodeinfo}/bin/nodeinfo > /var/lib/nodeinfo.nix";
        User = "root";
        Type = "simple";
        RemainAfterExit="yes";
        Restart = "on-failure";
        RestartSec = "10s";
      };

    };

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.operator = {
      isNormalUser = true;
      extraGroups = [ "clightning" config.services.bitcoind.group ];

    };
    environment.interactiveShellInit = ''
      alias bitcoin-cli='bitcoin-cli -datadir=${config.services.bitcoind.dataDir}'
      alias lightning-cli='sudo -u clightning lightning-cli --lightning-dir=${config.services.clightning.dataDir}'
    '';
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

  };
}
