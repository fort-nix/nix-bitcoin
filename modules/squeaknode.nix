{ config, lib, pkgs, ... }:

with lib;
let
  options.services.squeaknode = {
    enable = mkEnableOption "squeaknode";
    address = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to listen for peer connections";
    };
    port = mkOption {
      type = types.port;
      default = 8555;
      description = "Port to listen for peer connections";
    };
    rpcAddress = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to listen for RPC connections.";
    };
    rpcPort = mkOption {
      type = types.port;
      default = 8994;
      description = "Port to listen for gRPC connections.";
    };
    proxyHost = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.nix-bitcoin.torClientAddress else null;
      description = "host of SOCKS5 proxy for connnecting to other squeaknode peers.";
    };
    proxyPort = mkOption {
      type = types.nullOr types.str;
      default = if cfg.enforceTor then config.nix-bitcoin.torClientPort else null;
      description = "port of SOCKS5 proxy for connnecting to other squeaknode peers.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.squeaknode;
      description = "The package providing squeaknode binaries.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/squeaknode";
      description = "The data directory for squeaknode.";
    };
    getPublicAddressCmd = mkOption {
      type = types.str;
      default = "";
      description = ''
        Bash expression which outputs the public service address to announce to peers.
        If left empty, no address is announced.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "squeaknode";
      description = "The user as which to run squeaknode.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.squeaknode.user;
      description = "The group as which to run squeaknode.";
    };
    enforceTor = nbLib.enforceTor;
  };

  cfg = config.services.squeaknode;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  bitcoind = config.services.bitcoind;
  lnd = config.services.lnd;
  network = config.services.bitcoind.network;
  configFileTemplate = builtins.toFile "squeaknode.conf.tmpl" ''
  [node]
  network=${network}
  sqk_dir_path=${cfg.dataDir}
  max_squeaks=${}
  tor_proxy_ip=${cfg.proxyHost}
  tor_proxy_port=${cfg.proxyPort}
  external_address=''${NODE_EXTERNAL_ADDRESS}

  [bitcoin]
  rpc_host=${bitcoind.rpc.address}
  rpc_port=${toString bitcoind.rpc.port}
  rpc_user=${bitcoind.rpc.users.public.name}
  rpc_pass=''${BITCOIN_RPC_PASS}
  zeromq_hashblock_port=${bitcoind.zmqpubrawblock}

  [lnd]
  host=${lnd.rpcAddress}
  port=${lnd.rpcPort}
  tls_cert_path=${lnd.certPath}
  macaroon_path=${lnd.networkDir}/admin.macaroon

  [webadmin]
  enabled=true
  username=devuser
  password=devpass
  '';
in {
  inherit options;

  config = mkIf cfg.enable {
    services.lnd.enable = true;

    environment.systemPackages = [ cfg.package ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.lightning-loop = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service", "lnd.service" ];
      after = [ "bitcoind.service", "lnd.service" ];
      preStart = ''
        install -m600 ${configFileTemplate} '${cfg.dataDir}/squeaknode.conf'
        export BITCOIN_RPC_PASS=$(cat ${secretsDir}/bitcoin-rpcpassword-public)
        ${optionalString (cfg.getPublicAddressCmd != "") ''
          export NODE_EXTERNAL_ADDRESS=$(${cfg.getPublicAddressCmd})"
        eval "echo \"${configFileTemplate}\" > '${cfg.dataDir}/squeaknode.conf'
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${cfg.package}/bin/squeaknode --config=${cfg.dataDir}/squeaknode.conf";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowedIPAddresses cfg.enforceTor;
    };
  };
}
