{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin;
  secrets = import ../load-secrets.nix;
in {
  imports =
    [
      ./bitcoind.nix
      ./tor.nix
      ./clightning.nix
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
    services.bitcoind.rpcpassword = secrets.bitcoinrpcpassword;
    services.bitcoind.extraConfig = ''
      assumevalid=0000000000000000000726d186d6298b5054b9a5c49639752294b322a305d240
      addnode=ecoc5q34tmbq54wl.onion
      discover=0
    '';
    services.bitcoind.prune = 2000;

    # clightning
    services.clightning.enable = true;
    services.clightning.bitcoin-rpcuser = config.services.bitcoind.rpcuser;
    services.clightning.bitcoin-rpcpassword = config.services.bitcoind.rpcpassword;

    # nodeinfo
    systemd.services.nodeinfo = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      after = [ "clightning.service" "tor.service" ];
      path  = [ pkgs.clightning pkgs.jq pkgs.sudo ];
      serviceConfig = {
        ExecStart="${pkgs.bash}/bin/bash ${pkgs.nodeinfo}/bin/nodeinfo";
        User = "root";
        Type = "simple";
        RemainAfterExit="yes";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.guest = {
      isNormalUser = true;
    };
    systemd.services.copy-root-authorized-keys = {
      description = "Copy root authorized keys";
      wantedBy = [ "multi-user.target" ];
      path  = [ ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c \"mkdir -p ${config.users.users.guest.home}/.ssh && cp ${config.users.users.root.home}/.vbox-nixops-client-key ${config.users.users.guest.home}/.ssh/authorized_keys && chown -R guest ${config.users.users.guest.home}/.ssh\"";
        user = "root";
        type = "oneshot";
      };
    };

  };
}
