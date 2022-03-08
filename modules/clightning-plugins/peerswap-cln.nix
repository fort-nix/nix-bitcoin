{ config, lib, pkgs, ... }:

with lib;
let 
nbPkgs = config.nix-bitcoin.pkgs;
cfg = config.services.clightning.plugins.peerswap; 
configFile = builtins.toFile "policy.conf" ''
${optionalString (cfg.acceptallpeers != null) "accept_all_peers=${toString cfg.acceptallpeers}"}
${lib.concatMapStrings (nodeid: "allowlisted_peers=${nodeid}\n") cfg.allowlist}
'';
in
{
  options.services.clightning.plugins.peerswap = {
    enable = mkEnableOption "peerswap (clightning plugin)";
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.peerswap-cln;
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
  };
  
  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/peerswap
      peerswap-db-path=${config.services.clightning.dataDir}/peerswap/swaps
      peerswap-policy-path=${configFile}
      ${optionalString cfg.enableLiquid ''
        peerswap-liquid-rpchost=http://${config.services.liquidd.rpc.address}
        peerswap-liquid-rpcport=${toString config.services.liquidd.rpc.port}
        peerswap-liquid-rpcuser=${config.services.liquidd.rpcuser}
        peerswap-liquid-rpcpasswordfile=${config.nix-bitcoin.secretsDir}/liquid-rpcpassword
        peerswap-liquid-network=liquidv1
        peerswap-liquid-rpcwallet=${cfg.liquidRpcWallet}
      ''}
    '';
         
    users.users.${config.services.clightning.user}.extraGroups = optional cfg.enableLiquid config.services.liquidd.group;
  };
}