{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.backups;
  secretsDir = config.nix-bitcoin.secretsDir;

  filelist = pkgs.writeText "filelist.txt" ''
    ${optionalString (!cfg.with-bulk-data) "- ${config.services.bitcoind.dataDir}/blocks"}
    ${optionalString (!cfg.with-bulk-data) "- ${config.services.bitcoind.dataDir}/chainstate"}
    ${config.services.bitcoind.dataDir}
    ${config.services.clightning.dataDir}
    ${config.services.lnd.dataDir}
    ${secretsDir}/lnd-seed-mnemonic
    ${optionalString (!cfg.with-bulk-data) "- ${config.services.liquidd.dataDir}/*/blocks"}
    ${optionalString (!cfg.with-bulk-data) "- ${config.services.liquidd.dataDir}/*/chainstate"}
    ${config.services.liquidd.dataDir}
    ${optionalString cfg.with-bulk-data "${config.services.electrs.dataDir}"}
    ${config.services.nbxplorer.dataDir}
    ${config.services.btcpayserver.dataDir}
    ${config.services.joinmarket.dataDir}
    ${secretsDir}/jm-wallet-seed
    ${config.services.postgresqlBackup.location}/btcpaydb.sql.gz
    /var/lib/tor
    # Extra files
    ${cfg.extraFiles}

    # Exclude all unspecified files and directories
    - /
  '';
in {
  options.services.backups = {
    enable = mkEnableOption "Backups service";
    with-bulk-data = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to also backup Bitcoin blockchain and other bulk data.
      '';
    };
    destination = mkOption {
      type = types.str;
      default = "file:///var/lib/localBackups";
      description = ''
        Where to back up to.
      '';
    };
    frequency = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Run backup with the given frequency. If null, do not run automatically.
      '';
    };
    extraFiles = mkOption {
      type = types.lines;
      default = "";
      example = ''
        /var/lib/nginx
      '';
      description = "Additional files to be appended to filelist.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [ pkgs.duplicity ];

      services.duplicity = {
        enable = true;
        extraFlags = [
          "--include-filelist" "${filelist}"
          "--full-if-older-than" "1M"
        ];
        targetUrl = cfg.destination;
        frequency = cfg.frequency;
        secretFile = "${config.nix-bitcoin.secretsDir}/backup-encryption-env";
      };

      nix-bitcoin.secrets.backup-encryption-env.user = "root";
    }
    (mkIf config.services.btcpayserver.enable {
      services.postgresqlBackup = {
        enable = true;
        databases = [ "btcpaydb" ];
        startAt = [];
      };
      systemd.services.duplicity = rec {
        wants = [ "postgresqlBackup-btcpaydb.service" ];
        after = wants;
      };
    })
  ]);
}
