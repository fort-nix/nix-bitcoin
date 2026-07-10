{ config, lib, pkgs, ... }:

with lib;
let
  options.services.cdk-mintd = {
    enable = mkEnableOption "CDK Cashu mint daemon";

    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.cdk-mintd-static;
      defaultText = "config.nix-bitcoin.pkgs.cdk-mintd-static";
      description = "The cdk-mintd package.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/cdk-mintd";
      description = "The data directory for cdk-mintd.";
    };

    workDir = mkOption {
      type = types.path;
      default = cfg.dataDir;
      defaultText = "config.services.cdk-mintd.dataDir";
      description = ''
        Working directory passed to cdk-mintd. This is where SQLite databases
        are stored. Override this when migrating an existing mint that used a
        nested working directory.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "cdk-mintd";
      description = "The user as which to run cdk-mintd.";
    };

    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run cdk-mintd.";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for HTTP connections.";
    };

    port = mkOption {
      type = types.port;
      default = 8085;
      description = "Port to listen for HTTP connections.";
    };

    mintUrl = mkOption {
      type = types.str;
      example = "https://mint.example.com";
      description = "Public URL of the mint.";
    };

    lightningBackend = mkOption {
      type = types.enum [ "lnd" "cln" "fakewallet" ];
      default = "lnd";
      description = ''
        Lightning backend to use.
        Only LND, CLN, and fakewallet (for testing) are supported by this module.
      '';
    };

    tor = nbLib.tor;

    ln = {
      unit = mkOption {
        type = types.str;
        default = "sat";
        description = "Currency unit for the Lightning backend.";
      };

      minMint = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Minimum amount for a Lightning mint request (in sats).";
      };

      maxMint = mkOption {
        type = types.ints.unsigned;
        default = 500000;
        description = "Maximum amount for a Lightning mint request (in sats).";
      };

      minMelt = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Minimum amount for a Lightning melt request (in sats).";
      };

      maxMelt = mkOption {
        type = types.ints.unsigned;
        default = 500000;
        description = "Maximum amount for a Lightning melt request (in sats).";
      };
    };

    lnd = {
      address = mkOption {
        type = types.str;
        default = "https://${nbLib.addressWithPort config.services.lnd.rpcAddress config.services.lnd.rpcPort}";
        defaultText = ''"https://''${config.nix-bitcoin.lib.addressWithPort config.services.lnd.rpcAddress config.services.lnd.rpcPort}"'';
        description = "LND gRPC address.";
      };

      certFile = mkOption {
        type = types.path;
        default = config.services.lnd.certPath;
        defaultText = "config.services.lnd.certPath";
        description = "Path to LND TLS certificate.";
      };

      macaroonFile = mkOption {
        type = types.path;
        default = "${config.services.lnd.networkDir}/admin.macaroon";
        defaultText = "config.services.lnd.networkDir/admin.macaroon";
        description = "Path to LND admin macaroon.";
      };

      feePercent = mkOption {
        type = types.float;
        default = 0.02;
        description = "Fee percentage for Lightning operations.";
      };

      reserveFeeMin = mkOption {
        type = types.ints.unsigned;
        default = 2;
        description = "Minimum fee reserve in sats.";
      };
    };

    cln = {
      rpcPath = mkOption {
        type = types.path;
        default = "${config.services.clightning.networkDir}/lightning-rpc";
        defaultText = "config.services.clightning.networkDir/lightning-rpc";
        description = "Path to CLN RPC socket.";
      };

      feePercent = mkOption {
        type = types.float;
        default = 0.02;
        description = "Fee percentage for Lightning operations.";
      };

      reserveFeeMin = mkOption {
        type = types.ints.unsigned;
        default = 2;
        description = "Minimum fee reserve in sats.";
      };
    };

    fakeWallet = {
      feePercent = mkOption {
        type = types.float;
        default = 0.02;
        description = "Fee percentage for fake wallet operations.";
      };

      reserveFeeMin = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Minimum fee reserve in sats.";
      };

      minDelayTime = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Minimum fake payment delay time (seconds).";
      };

      maxDelayTime = mkOption {
        type = types.ints.unsigned;
        default = 3;
        description = "Maximum fake payment delay time (seconds).";
      };
    };

    limits = {
      maxInputs = mkOption {
        type = types.ints.unsigned;
        default = 1000;
        description = "Maximum number of inputs allowed per transaction.";
      };

      maxOutputs = mkOption {
        type = types.ints.unsigned;
        default = 1000;
        description = "Maximum number of outputs allowed per transaction.";
      };
    };

    mintInfo = {
      name = mkOption {
        type = types.str;
        default = "";
        example = "My Cashu Mint";
        description = "Name of the mint.";
      };

      description = mkOption {
        type = types.str;
        default = "";
        example = "A production Cashu mint running on nix-bitcoin.";
        description = "Short description of the mint.";
      };

      descriptionLong = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Longer description of the mint and its policies.";
        description = "Long description of the mint.";
      };

      iconUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://mint.example.com/icon.png";
        description = "URL to the mint icon.";
      };

      motd = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Welcome to the mint.";
        description = "Message of the day that wallets must display to users.";
      };

      contact = {
        nostrPublicKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "npub1...";
          description = "Nostr public key for mint contact.";
        };

        email = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "operator@example.com";
          description = "Contact email for the mint.";
        };
      };

      tosUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://mint.example.com/tos";
        description = "URL to the terms of service.";
      };

      pubkey = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "02...";
        description = ''
          Hex pubkey of the mint. If unset, the mint derives a pubkey from
          the configured mnemonic.
        '';
      };
    };

    database = {
      engine = mkOption {
        type = types.enum [ "sqlite" ];
        default = "sqlite";
        description = "Database engine. Only SQLite is supported by this module.";
      };
    };

    backup = {
      enable = mkEnableOption "automated SQLite backups for the mint";

      location = mkOption {
        type = types.path;
        default = "${cfg.dataDir}/backups";
        description = ''
          Directory where SQLite backup files are written.
          Use a separate filesystem or remote backup destination in production.
        '';
      };

      frequency = mkOption {
        type = types.str;
        default = "daily";
        example = "hourly";
        description = ''
          systemd calendar expression for the backup timer.
          See systemd.time(7) for the format.
        '';
      };

      retention = mkOption {
        type = types.ints.unsigned;
        default = 7;
        description = ''
          Number of backup snapshots to keep. Older backups are deleted
          after each successful run. Set to 0 to keep all backups.
        '';
      };
    };

    cli = {
      enable = mkEnableOption "CDK CLI wallet" // {
        default = true;
      };

      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.cdk-cli-static;
        defaultText = "config.nix-bitcoin.pkgs.cdk-cli-static";
        description = "The cdk-cli package.";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open the firewall for the mint HTTP port.
        Only enable if you are exposing the mint directly without a reverse proxy.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra lines appended to the cdk-mintd config file.
        See the CDK documentation for all available options.
        This configuration is written to the world-readable Nix store and
        must never contain mnemonics, passwords, tokens, or other secrets.
      '';
    };
  };

  cfg = config.services.cdk-mintd;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  lnd = config.services.lnd;
  clightning = config.services.clightning;

  credentialDir = "/run/credentials/cdk-mintd.service";
  mnemonicCredential = "${credentialDir}/mnemonic";
  lndMacaroonCredential = "${credentialDir}/lnd-macaroon";

  # CDK v0.17.1 creates SQLite databases directly under CDK_MINTD_WORK_DIR,
  # not in a `.cdk-mintd` subdirectory.
  sqliteDb = "${cfg.workDir}/cdk-mintd.sqlite";
  sqliteAuthDb = "${cfg.workDir}/cdk-mintd-auth.sqlite";
  mnemonicPython = pkgs.python3.withPackages (ps: [ ps.mnemonic ]);

  mintInfoEnabled =
    (cfg.mintInfo.name != ""
      || cfg.mintInfo.description != ""
      || cfg.mintInfo.descriptionLong != null
      || cfg.mintInfo.iconUrl != null
      || cfg.mintInfo.motd != null
      || cfg.mintInfo.contact.nostrPublicKey != null
      || cfg.mintInfo.contact.email != null
      || cfg.mintInfo.tosUrl != null
      || cfg.mintInfo.pubkey != null);

  toml = pkgs.formats.toml { };
  generatedConfig = toml.generate "cdk-mintd-config-generated.toml" ({
    info = {
      url = cfg.mintUrl;
      listen_host = cfg.address;
      listen_port = cfg.port;
    };
    ln = {
      ln_backend = cfg.lightningBackend;
      unit = cfg.ln.unit;
      min_mint = cfg.ln.minMint;
      max_mint = cfg.ln.maxMint;
      min_melt = cfg.ln.minMelt;
      max_melt = cfg.ln.maxMelt;
    };
    database.engine = cfg.database.engine;
    limits = {
      max_inputs = cfg.limits.maxInputs;
      max_outputs = cfg.limits.maxOutputs;
    };
  }
  // optionalAttrs (cfg.lightningBackend == "lnd") {
    lnd = {
      address = cfg.lnd.address;
      cert_file = toString cfg.lnd.certFile;
      macaroon_file = lndMacaroonCredential;
      fee_percent = cfg.lnd.feePercent;
      reserve_fee_min = cfg.lnd.reserveFeeMin;
    };
  }
  // optionalAttrs (cfg.lightningBackend == "cln") {
    cln = {
      rpc_path = toString cfg.cln.rpcPath;
      fee_percent = cfg.cln.feePercent;
      reserve_fee_min = cfg.cln.reserveFeeMin;
    };
  }
  // optionalAttrs (cfg.lightningBackend == "fakewallet") {
    fake_wallet = {
      fee_percent = cfg.fakeWallet.feePercent;
      reserve_fee_min = cfg.fakeWallet.reserveFeeMin;
      min_delay_time = cfg.fakeWallet.minDelayTime;
      max_delay_time = cfg.fakeWallet.maxDelayTime;
    };
  }
  // optionalAttrs mintInfoEnabled {
    mint_info = {
      name = cfg.mintInfo.name;
      description = cfg.mintInfo.description;
    }
    // optionalAttrs (cfg.mintInfo.descriptionLong != null) { description_long = cfg.mintInfo.descriptionLong; }
    // optionalAttrs (cfg.mintInfo.iconUrl != null) { icon_url = cfg.mintInfo.iconUrl; }
    // optionalAttrs (cfg.mintInfo.motd != null) { motd = cfg.mintInfo.motd; }
    // optionalAttrs (cfg.mintInfo.contact.nostrPublicKey != null) { contact_nostr_public_key = cfg.mintInfo.contact.nostrPublicKey; }
    // optionalAttrs (cfg.mintInfo.contact.email != null) { contact_email = cfg.mintInfo.contact.email; }
    // optionalAttrs (cfg.mintInfo.tosUrl != null) { tos_url = cfg.mintInfo.tosUrl; }
    // optionalAttrs (cfg.mintInfo.pubkey != null) { pubkey = cfg.mintInfo.pubkey; };
  });
  extraConfigFile = pkgs.writeText "cdk-mintd-extra-config.toml" cfg.extraConfig;
  configFile = if cfg.extraConfig == "" then generatedConfig else pkgs.runCommand
    "cdk-mintd-config.toml" { } ''
      cat ${generatedConfig} ${extraConfigFile} > "$out"
    '';

  launcher = pkgs.writeShellScript "cdk-mintd-launcher" ''
    set -eo pipefail
    CDK_MINTD_WORK_DIR="${cfg.workDir}"
    export CDK_MINTD_WORK_DIR
    exec ${cfg.package}/bin/cdk-mintd --config ${configFile} --seed-file ${mnemonicCredential}
  '';
in
{
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.lightningBackend == "lnd" -> lnd.enable;
        message = ''
          services.cdk-mintd with lightningBackend = "lnd" requires services.lnd.enable = true.
        '';
      }
      {
        assertion = cfg.lightningBackend == "cln" -> clightning.enable;
        message = ''
          services.cdk-mintd with lightningBackend = "cln" requires services.clightning.enable = true.
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ] ++ optional (cfg.workDir != cfg.dataDir)
      "d '${cfg.workDir}' 0750 ${cfg.user} ${cfg.group} - -";

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      extraGroups = optional (cfg.lightningBackend == "cln") clightning.group;
    };
    users.groups.${cfg.group} = { };

    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      allowRunAsUsers = [ cfg.user ];
    };

    nix-bitcoin.secrets."cdk-mintd-mnemonic" = {
      user = cfg.user;
      group = cfg.group;
      permissions = "640";
    };
    nix-bitcoin.generateSecretsCmds.cdk-mintd = mkDefault ''
      if [[ ! -e cdk-mintd-mnemonic ]]; then
        ${mnemonicPython}/bin/python -c \
          'from mnemonic import Mnemonic; print(Mnemonic("english").generate(strength=256))' \
          > cdk-mintd-mnemonic
      fi
    '';

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    environment.systemPackages = mkIf cfg.cli.enable [ cfg.cli.package ];

    systemd.services.cdk-mintd = {
      description = "CDK Cashu Mint Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "nix-bitcoin-secrets.target" ]
        ++ optional (cfg.lightningBackend == "lnd") "lnd.service"
        ++ optional (cfg.lightningBackend == "cln") "clightning.service";
      requires = [ ]
        ++ optional (cfg.lightningBackend == "lnd") "lnd.service"
        ++ optional (cfg.lightningBackend == "cln") "clightning.service";

      serviceConfig = nbLib.defaultHardening // {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workDir;
        ExecStart = launcher;
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "5min";
        LimitCORE = 0;
        UMask = "0027";
        ReadWritePaths = unique [ cfg.dataDir cfg.workDir ]
          ++ optional (cfg.lightningBackend == "cln") (dirOf cfg.cln.rpcPath);
        LoadCredential = [ "mnemonic:${secretsDir}/cdk-mintd-mnemonic" ]
          ++ optional (cfg.lightningBackend == "lnd") "lnd-macaroon:${cfg.lnd.macaroonFile}";
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    systemd.services.cdk-mintd-backup = mkIf (cfg.database.engine == "sqlite" && cfg.backup.enable) {
      description = "CDK mint SQLite backup";
      path = [ pkgs.sqlite ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir cfg.backup.location ];
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateNetwork = true;
        UMask = "0027";
      };
      script = ''
        set -euo pipefail

        install -d -m 750 -o ${cfg.user} -g ${cfg.group} ${cfg.backup.location}

        backup_dir="${cfg.backup.location}"
        timestamp=$(date +%Y%m%d-%H%M%S)

        # The main database must exist; backup failures propagate because the
        # service now exits non-zero on any error.
        ${pkgs.sqlite}/bin/sqlite3 ${sqliteDb} ".backup ''$backup_dir/cdk-mintd-''$timestamp.sqlite"

        # The auth database is only created when authentication is enabled.
        if [ -f ${sqliteAuthDb} ]; then
          ${pkgs.sqlite}/bin/sqlite3 ${sqliteAuthDb} ".backup ''$backup_dir/cdk-mintd-auth-''$timestamp.sqlite"
        fi

        retention=${toString cfg.backup.retention}
        if [ "$retention" -gt 0 ]; then
          for prefix in cdk-mintd cdk-mintd-auth; do
            find "''$backup_dir" -maxdepth 1 -type f -name "''$prefix-*.sqlite" -printf '%T@ %p\n' \
              | sort -nr \
              | tail -n +$((retention + 1)) \
              | cut -d' ' -f2- \
              | while read -r f; do
                  rm -f "''$f"
                done
          done
        fi
      '';
    };

    systemd.timers.cdk-mintd-backup = mkIf (cfg.database.engine == "sqlite" && cfg.backup.enable) {
      description = "Timer for CDK mint SQLite backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.frequency;
        Persistent = true;
      };
    };

    services.backups.extraFiles = mkIf config.services.backups.enable [ cfg.dataDir ];
  };
}
