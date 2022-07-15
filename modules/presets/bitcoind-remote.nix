{ config, lib, pkgs, ... }:

let
  cfg = config.services.bitcoind;
  secretsDir = config.nix-bitcoin.secretsDir;
in {
  services.bitcoind = {
    # Make the local bitcoin-cli work with the remote node
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
