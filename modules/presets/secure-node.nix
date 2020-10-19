{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;

  operatorName = config.nix-bitcoin.operator.name;

  mkHiddenService = map: {
    map = [ map ];
    version = 3;
  };
in {
  imports = [
    ../modules.nix
    ../nodeinfo.nix
    ../nix-bitcoin-webindex.nix
  ];

  options = {
    services.clightning.onionport = mkOption {
      type = types.port;
      default = 9735;
      description = "Port on which to listen for tor client connections.";
    };
    services.lnd.onionport = mkOption {
      type = types.ints.u16;
      default = 9735;
      description = "Port on which to listen for tor client connections.";
    };
  };

  config =  {
    # For backwards compatibility only
    nix-bitcoin.secretsDir = mkDefault "/secrets";

    networking.firewall.enable = true;

    nix-bitcoin.security.hideProcessInformation = true;

    # Tor
    services.tor = {
      enable = true;
      client.enable = true;

      hiddenServices.sshd = mkHiddenService { port = 22; };
    };

    # bitcoind
    services.bitcoind = {
      enable = true;
      listen = true;
      dataDirReadableByGroup = mkIf cfg.electrs.high-memory true;
      enforceTor = true;
      port = 8333;
      assumevalid = "00000000000000000000e5abc3a74fe27dc0ead9c70ea1deb456f11c15fd7bc6";
      addnodes = [ "ecoc5q34tmbq54wl.onion" ];
      discover = false;
      addresstype = "bech32";
      dbCache = 1000;
      # higher rpcthread count due to reports that lightning implementations fail
      # under high bitcoind rpc load
      rpcthreads = 16;
    };
    services.tor.hiddenServices.bitcoind = mkHiddenService { port = cfg.bitcoind.port; toHost = cfg.bitcoind.bind; };

    # clightning
    services.clightning.enforceTor = true;
    services.tor.hiddenServices.clightning = mkIf cfg.clightning.enable (mkHiddenService {
      port = cfg.clightning.onionport;
      toHost = cfg.clightning.bind-addr;
      toPort = cfg.clightning.bindport;
    });

    # lnd
    services.lnd.enforceTor = true;
    services.tor.hiddenServices.lnd = mkIf cfg.lnd.enable (mkHiddenService { port = cfg.lnd.onionport; toHost = cfg.lnd.listen; toPort = cfg.lnd.listenPort; });

    # lightning-loop
    services.lightning-loop.enforceTor = true;

    # liquidd
    services.liquidd = {
      rpcuser = "liquidrpc";
      prune = 1000;
      validatepegin = true;
      listen = true;
      enforceTor = true;
      port = 7042;
    };
    services.tor.hiddenServices.liquidd = mkIf cfg.liquidd.enable (mkHiddenService { port = cfg.liquidd.port; toHost = cfg.liquidd.bind; });

    # electrs
    services.electrs = {
      port = 50001;
      enforceTor = true;
    };
    services.tor.hiddenServices.electrs = mkIf cfg.electrs.enable (mkHiddenService {
      port = cfg.electrs.port; toHost = cfg.electrs.address;
    });

    # btcpayserver
    # disable tor enforcement until btcpayserver can fetch rates over Tor
    services.btcpayserver.enforceTor = false;
    services.nbxplorer.enforceTor = true;
    services.tor.hiddenServices.btcpayserver = mkIf cfg.btcpayserver.enable (mkHiddenService { port = 80; toPort = 23000; toHost = cfg.btcpayserver.bind; });

    services.spark-wallet = {
      onion-service = true;
      enforceTor = true;
    };

    services.lightning-charge.enforceTor = true;

    services.nanopos.enforceTor = true;

    services.recurring-donations.enforceTor = true;

    services.nix-bitcoin-webindex.enforceTor = true;

    # Backups
    services.backups = {
      program = "duplicity";
      frequency = "daily";
    };

    environment.systemPackages = with pkgs; [
      tor
      jq
      qrencode
    ];

    services.onion-chef = {
      enable = true;
      access.${operatorName} = [ "bitcoind" "clightning" "nginx" "liquidd" "spark-wallet" "electrs" "btcpayserver" "sshd" ];
    };

    nix-bitcoin.operator.enable = true;
    users.users.${operatorName} = {
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
    };
    # Enable nixops ssh for operator (`nixops ssh operator@mynode`) on nixops-vbox deployments
    systemd.services.get-vbox-nixops-client-key =
      mkIf (builtins.elem ".vbox-nixops-client-key" config.services.openssh.authorizedKeysFiles) {
        postStart = ''
          cp "${config.users.users.root.home}/.vbox-nixops-client-key" "${config.users.users.${operatorName}.home}"
        '';
      };
  };
}
