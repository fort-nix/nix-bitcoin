{ config, lib, pkgs, ... }:

with lib;
let
  options.services.lianad = {
    enable = mkEnableOption "lianad bitcoin wallet";
    daemon = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Whether to run the process as a UNIX daemon (double fork magic).";
    };
    data_dir = mkOption {
      type = types.path;
      default = "/var/lib/lianad";
      description = mdDoc "Path to the folder where we should store the application data.";
    };
    main_descriptor = mkOption {
      type = types.str;
      default = "wsh(or_d(pk([0dd8c6f0/48'/1'/0'/2']tpubDFMbZ7U5k5hEfsttnZTKMmwrGMHnqUGxhShsvBjHimXBpmAp5KmxpyGsLx2toCaQgYq5TipBLhTUtA2pRSB9b14m5KwSohTDoCHkk1EnqtZ/<0;1>/*),and_v(v:pkh([d4ab66f1/48'/1'/0'/2']tpubDEXYN145WM4rVKtcWpySBYiVQ229pmrnyAGJT14BBh2QJr7ABJswchDicZfFaauLyXhDad1nCoCZQEwAW87JPotP93ykC9WJvoASnBjYBxW/<0;1>/*),older(65535))))#7nvn6ssc";
      description = mdDoc "The wallet descriptor.";
    };
    network = mkOption {
      type = types.str;
      default = "bitcoin";
      description = mdDoc "bitcoin, testnet, signet, or regtest";
    };
    bitcoind_addr = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = mdDoc "bitcoind address.";
    };
    bitcoind_port = mkOption {
      type = types.port;
      default = 8332;
      description = mdDoc "bitcoind port.";
    };
  };

  cfg = config.services.lianad;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind = {
      enable = true;
      listenWhitelisted = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.lianad = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" "nix-bitcoin-secrets.target" ];
      preStart = ''
        cat << EOF > lianad_config.toml
# these should come from options.services.lianad
daemon = false
data_dir = "/var/lib/lianad"
log_level = "debug"
main_descriptor = "wsh(or_d(pk([0dd8c6f0/48'/1'/0'/2']tpubDFMbZ7U5k5hEfsttnZTKMmwrGMHnqUGxhShsvBjHimXBpmAp5KmxpyGsLx2toCaQgYq5TipBLhTUtA2pRSB9b14m5KwSohTDoCHkk1EnqtZ/<0;1>/*),and_v(v:pkh([d4ab66f1/48'/1'/0'/2']tpubDEXYN145WM4rVKtcWpySBYiVQ229pmrnyAGJT14BBh2QJr7ABJswchDicZfFaauLyXhDad1nCoCZQEwAW87JPotP93ykC9WJvoASnBjYBxW/<0;1>/*),older(65535))))#7nvn6ssc"

# these should come from options.services.lianad
[bitcoin_config]
network = "signet"
poll_interval_secs = 30

# these should come from options.services.bitcoind
[bitcoind_config]
addr = "127.0.0.1:38332"
auth = "username:password"

EOF
        '';
      serviceConfig = nbLib.defaultHardening // {
        # lianad only uses the working directory for reading lianad_config.toml
        WorkingDirectory = cfg.dataDir;
        ExecStart = ''
          ${config.nix-bitcoin.pkgs.lianad}/bin/lianad \
          --conf lianad_config.toml
        '';
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}
