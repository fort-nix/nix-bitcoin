{ config, lib, pkgs, ... }:

let
  cfg = config.services.bitcoind;
  secretsDir = config.nix-bitcoin.secretsDir;
in {
  services.bitcoind = {
    # Make the local bitcoin-cli work with the remote node.
    # Without this, bitcoin-cli would try to use the .cookie file in the local
    # bitcoind data dir for authorization, which doesn't exist.
    extraConfig = ''
      rpcuser=${cfg.rpc.users.privileged.name}
    '';
  };

  systemd.services.bitcoind = {
    preStart = lib.mkAfter ''
      echo "rpcpassword=$(cat ${secretsDir}/bitcoin-rpcpassword-privileged)" >> '${cfg.dataDir}/bitcoin.conf'
    '';
    postStart = lib.mkForce "";
    serviceConfig = {
      Type = lib.mkForce "oneshot";
      ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
      RemainAfterExit = true;
    };
  };
}
