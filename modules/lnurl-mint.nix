{ config, lib, pkgs, ... }:

with lib;
let
  options.services.lnurl-mint = {
    enable = mkEnableOption "lnurl-mint, a minimal lnurlcash (LUD-25) Lightning bearer-note mint";

    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.lnurl-mint;
      defaultText = "config.nix-bitcoin.pkgs.lnurl-mint";
      description = "The lnurl-mint package.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lnurl-mint";
      description = ''
        The data directory for lnurl-mint - mint.db (sqlite, including its
        journal/WAL files) and the mint/error logs live here.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "lnurl-mint";
      description = "The user as which to run lnurl-mint.";
    };

    group = mkOption {
      type = types.str;
      default = cfg.user;
      defaultText = "config.services.lnurl-mint.user";
      description = "The group as which to run lnurl-mint.";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for HTTP connections.";
    };

    port = mkOption {
      type = types.port;
      default = 8111;
      description = "Port to listen for HTTP connections.";
    };

    mintUrl = mkOption {
      type = types.str;
      example = "https://mint.example.com";
      description = ''
        Public base URL of the mint (BASE_URL). Required: callback and
        withdraw URLs handed to wallets are built from it, never from a
        request's Host header (which any caller - or a Host-agnostic cache -
        can spoof).
      '';
    };

    lightningBackend = mkOption {
      type = types.enum [
        "lnd"
        "cln"
      ];
      default = "lnd";
      description = ''
        Lightning node funding this mint (its FUNDINGSOURCE). Only lnd and
        cln are supported by this module. Without one, minting, melting and
        offline verification are unavailable (rotate/split/merge of existing
        notes still work).
      '';
    };

    verifyEnabled = mkOption {
      type = types.bool;
      default = true;
      description = ''
        VERIFY_ENABLED (LUD-21): serve /verify/{payment_hash} and advertise
        it in /p/cb and melt responses, so wallets without their own node
        can poll settlement. Note: a settled mint response's preimage IS the
        bearer note's spend secret, served to any holder of the payment hash
        (which travels inside the invoice itself) - see lnurl-mint's README
        section "The observer race, plainly". false disables the endpoint
        entirely (404).
      '';
    };

    fees = {
      baseMsat = mkOption {
        type = types.ints.unsigned;
        default = 1000;
        description = "BASE_FEE_MSAT: flat fee withheld from every minted note.";
      };

      percentPpm = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = ''
          FEE_PERCENT_PPM: parts-per-million cut of every mint, on top of
          baseMsat. Must stay well below 1000000 (100%) - the mint rejects
          higher values at startup.
        '';
      };
    };

    lnd = {
      address = mkOption {
        type = types.str;
        default = "https://${nbLib.addressWithPort config.services.lnd.restAddress config.services.lnd.restPort}";
        defaultText = ''"https://''${config.nix-bitcoin.lib.addressWithPort config.services.lnd.restAddress config.services.lnd.restPort}"'';
        description = "LND REST address (FUNDINGSOURCE_URL).";
      };

      certFile = mkOption {
        type = types.path;
        default = config.services.lnd.certPath;
        defaultText = "config.services.lnd.certPath";
        description = "Path to the LND TLS certificate (FUNDINGSOURCE_CERT_PATH).";
      };

      macaroonFile = mkOption {
        type = types.path;
        default = "${config.services.lnd.networkDir}/admin.macaroon";
        defaultText = "config.services.lnd.networkDir/admin.macaroon";
        description = ''
          Path to the LND macaroon. Scope it to what lnurl-mint actually
          calls instead of using admin.macaroon (see its README):
          invoices:write invoices:read offchain:write offchain:read
          message:write info:read.
        '';
      };
    };

    cln = {
      address = mkOption {
        type = types.str;
        default = "https://${nbLib.addressWithPort clnrest.address clnrest.port}";
        defaultText = ''"https://''${config.nix-bitcoin.lib.addressWithPort config.services.clightning.plugins.clnrest.address config.services.clightning.plugins.clnrest.port}"'';
        description = "clnrest address (FUNDINGSOURCE_URL).";
      };

      runeFile = mkOption {
        type = types.path;
        default = "${config.services.clightning.networkDir}/lnurl-mint-rune";
        defaultText = "config.services.clightning.networkDir/lnurl-mint-rune";
        description = ''
          Path to the CLN rune (FUNDINGSOURCE_RUNE). Created automatically on
          first start, scoped to just the methods lnurl-mint calls (invoice,
          xpay, signmessage, listinvoices, listpays, getinfo).
        '';
      };

      certFile = mkOption {
        type = types.path;
        default = "${config.services.clightning.networkDir}/ca.pem";
        defaultText = "config.services.clightning.networkDir/ca.pem";
        description = ''
          Path to the clnrest CA certificate (FUNDINGSOURCE_CERT_PATH) -
          clnrest's certs are self-signed, so the mint needs the CA to
          verify the connection. Generated by clnrest on first start.
        '';
      };
    };

    tor = nbLib.tor;

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open the firewall for the mint HTTP port.
        Only enable if you are exposing the mint directly without a reverse proxy.
      '';
    };

    extraSettings = mkOption {
      type = types.attrsOf (types.oneOf [
        types.str
        types.int
        types.bool
      ]);
      default = { };
      example = {
        TITLE = "My mint";
        MIN_MINT_MSAT = 10000;
      };
      description = ''
        Extra environment variables for the mint (see lnurl-mint's
        .env.example for the full list), rendered 1:1 as KEY=value. Wins
        over the dedicated options on conflict. Written to the
        world-readable Nix store - never put secrets (macaroons, runes)
        here; the module wires those via systemd credentials instead.
      '';
    };
  };

  cfg = config.services.lnurl-mint;
  nbLib = config.nix-bitcoin.lib;

  lnd = config.services.lnd;
  clightning = config.services.clightning;
  clnrest = clightning.plugins.clnrest;

  isLnd = cfg.lightningBackend == "lnd";
  isCln = cfg.lightningBackend == "cln";

  credentialDir = "/run/credentials/lnurl-mint.service";

  toEnvValue = v: if builtins.isBool v then (if v then "true" else "false") else toString v;

  # lnurl-mint takes its node credentials as env vars; nix-bitcoin handles
  # secrets as files (LoadCredential) - the launcher bridges the two. The
  # lnd cert goes through a credential too: readable by root regardless of
  # the lnd data dir's permissions, and stable across restarts.
  launcher = pkgs.writeShellScript "lnurl-mint-launcher" ''
    set -eo pipefail
    ${optionalString isLnd ''
      FUNDINGSOURCE_MACAROON="$(${pkgs.unixtools.xxd}/bin/xxd -p -c 1000 '${credentialDir}/lnd-macaroon' | tr -d '\n')"
      export FUNDINGSOURCE_MACAROON
    ''}
    ${optionalString isCln ''
      FUNDINGSOURCE_RUNE="$(tr -d '[:space:]' < '${credentialDir}/cln-rune')"
      export FUNDINGSOURCE_RUNE
    ''}
    exec ${cfg.package}/bin/lnurl-mint --host ${nbLib.address cfg.address} --port ${toString cfg.port}
  '';
in
{
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = isLnd -> lnd.enable;
        message = ''
          services.lnurl-mint with lightningBackend = "lnd" requires services.lnd.enable = true.
        '';
      }
      {
        assertion = isCln -> clightning.enable;
        message = ''
          services.lnurl-mint with lightningBackend = "cln" requires services.clightning.enable = true.
        '';
      }
      {
        assertion = isCln -> clnrest.enable;
        message = ''
          services.lnurl-mint with lightningBackend = "cln" requires services.clightning.plugins.clnrest.enable = true
          (lnurl-mint talks to CLN over its REST API).
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = { };

    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      allowRunAsUsers = [ cfg.user ];
    };

    # mint the rune lnurl-mint starts with - scoped to exactly the methods
    # it calls (see its README), created once, alongside clnrest's own
    # admin-rune handling
    systemd.services.clightning.postStart = mkIf isCln (mkAfter ''
      if [[ ! -e '${cfg.cln.runeFile}' ]]; then
        rune=$(${clightning.cli}/bin/lightning-cli createrune \
          restrictions='[["method=invoice","method=xpay","method=signmessage","method=listinvoices","method=listpays","method=getinfo","method=listchannels"]]' \
          | ${pkgs.jq}/bin/jq -r .rune)
        install -m 640 <(echo "$rune") '${cfg.cln.runeFile}'
      fi
    '');

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.lnurl-mint = {
      description = "lnurlcash (LUD-25) bearer-note mint";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "nix-bitcoin-secrets.target" ]
        ++ optional isLnd "lnd.service"
        ++ optional isCln "clightning.service";
      requires =
        optional isLnd "lnd.service"
        ++ optional isCln "clightning.service";

      environment = {
        DATABASE_PATH = "${cfg.dataDir}/mint.db";
        BASE_URL = cfg.mintUrl;
        VERIFY_ENABLED = toEnvValue cfg.verifyEnabled;
        BASE_FEE_MSAT = toString cfg.fees.baseMsat;
        FEE_PERCENT_PPM = toString cfg.fees.percentPpm;
        FUNDINGSOURCE_BACKEND = cfg.lightningBackend;
        FUNDINGSOURCE_URL = if isLnd then cfg.lnd.address else cfg.cln.address;
        # both REST APIs are commonly self-signed; the cert travels as a
        # credential, readable by root regardless of the backend data dir's
        # permissions
        FUNDINGSOURCE_CERT_PATH = "${credentialDir}/node-cert";
      }
      // mapAttrs (_: toEnvValue) cfg.extraSettings;

      serviceConfig = nbLib.defaultHardening // {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = launcher;
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "5min";
        LimitCORE = 0;
        UMask = "0027";
        ReadWritePaths = [ cfg.dataDir ];
        LoadCredential =
          optional isLnd "lnd-macaroon:${cfg.lnd.macaroonFile}"
          ++ optional isCln "cln-rune:${cfg.cln.runeFile}"
          ++ [ "node-cert:${if isLnd then cfg.lnd.certFile else cfg.cln.certFile}" ];
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    services.backups.extraFiles = mkIf config.services.backups.enable [ cfg.dataDir ];
  };
}
