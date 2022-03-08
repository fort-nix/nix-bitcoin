{ config, lib, pkgs, ... }:

with lib;
let 
  nbPkgs = config.nix-bitcoin.pkgs;
  cfg = config.services.peerswap-lnd;
  nbLib = config.nix-bitcoin.lib;

  options.services.peerswap-lnd = {
    enable = mkEnableOption "peerswap lnd";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.peerswap-lnd;
      description = "The package providing peerswap binaries.";
    };
    allowlist = mkOption {
      type = types.listOf types.str;
      default = [""];
      description = ''
        Only node ids in the allowlist can send a peerswap request to your node.
      '';
    };
    acceptallpeers = mkOption {
      type = types.nullOr types.bool;
        default = null;
        description = "UNSAFE Allow all peers to swap with your node";
    };
    rpcAddress = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to listen for gRPC connections.";
    };
    rpcPort = mkOption {
      type = types.port;
      default = 42069;
      description = "Port to listen for gRPC connections.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/peerswap-lnd";
      description = "The data directory for peerswap.";
    };
    enableLiquid = mkOption {
      type = types.bool;
        default = config.services.liquidd.enable;
        description = "enables l-btc swaps";
    };
    enableBitcoin = mkOption {
      type = types.bool;
        default = true;
        description = "enables bitcoin swaps";
    };
    liquidRpcWallet = mkOption {
      type = types.str;
      default = "peerswap";
      description = "The liquid rpc wallet to use peerswap with";
    };
    user = mkOption {
      type = types.str;
      default = "peerswap";
      description = "The user as which to run PeerSwap.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run PeerSwap.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "pscli" ''
        ${cfg.package}/bin/pscli --rpchost=${nbLib.addressWithPort cfg.rpcAddress cfg.rpcPort} "$@"
      '';
      defaultText = "(See source)";
      description = "Binary to connect with the peerswap instance.";
    };
  };

  configFile = builtins.toFile "peerswap.conf" ''
    ${optionalString (cfg.acceptallpeers != null) "accept_all_peers=${toString cfg.acceptallpeers}"}
    host=${nbLib.addressWithPort cfg.rpcAddress cfg.rpcPort}
    lnd.macaroonpath=${cfg.dataDir}/peerswap.macaroon
    lnd.tlscertpath=${lnd.certPath}
    lnd.host=${nbLib.addressWithPort lnd.rpcAddress lnd.rpcPort}
    bitcoinswaps=${toString cfg.enableBitcoin}
    datadir=${cfg.dataDir}
    ${optionalString cfg.enableLiquid ''
    liquid.rpchost=http://${config.services.liquidd.rpc.address}
    liquid.rpcport=${toString config.services.liquidd.rpc.port}
    liquid.rpcuser=${config.services.liquidd.rpcuser}
    liquid.rpcpasswordfile=${config.nix-bitcoin.secretsDir}/liquid-rpcpassword
    liquid.network=liquidv1
    liquid.rpcwallet=${cfg.liquidRpcWallet}
    ''}
    ${lib.concatMapStrings (nodeid: "allowlisted_peers=${nodeid}\n") cfg.allowlist}
  '';

  inherit (config.services)
    liquidd
    lnd;
in
{
  inherit options;
  config = mkIf cfg.enable {
      
    services.lnd.enable = true;
    services.lnd.macaroons.peerswap = {
      user = cfg.user;
      permissions = ''{"entity": "info","action": "read"},{"entity": "onchain","action": "write"},{"entity": "onchain","action": "read"},{"entity": "invoices","action": "write"},{"entity": "invoices","action": "read"},{"entity": "offchain","action": "write"},{"entity": "offchain","action": "read"},{"entity": "peers","action": "read"}'';
    };

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${lnd.user} ${lnd.group} - -"
    ];
    

    systemd.services.peerswap-lnd = {
      description = "peerswap initialize script";
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      preStart = ''
      macaroonDir=${cfg.dataDir}
      ln -sf /run/lnd/peerswap.macaroon $macaroonDir
      '';
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/peerswapd --configfile=${configFile}";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      extraGroups =
        [ lnd.group ]
        ++ optional cfg.enableLiquid liquidd.group;
    };
    users.groups.${cfg.group} = {};
  };
}