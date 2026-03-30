{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.services.albyhub;
  nbLib = config.nix-bitcoin.lib;
  bitcoind = config.services.bitcoind;
  lnd = config.services.lnd;
  # Use loopback for client connections if lnd is bound to wildcard addresses
  lndRpcClientAddress = builtins.replaceStrings [ "0.0.0.0" "[::]" ] [ "127.0.0.1" "[::1]" ] lnd.rpcAddress;
  torRelays = [
    "ws://oxtrdevav64z64yb7x6rjg4ntzqjhedm5b5zjqulugknhzr46ny2qbad.onion"
    "ws://bitcoinr6de5lkvx4tpwdmzrdfdpla5sya2afwpcabjup2xpi5dulbad.onion"
  ];

  envFileContent =
    let
      backendOpts =
        if cfg.lnBackend == "lnd" then
          ''
            LN_BACKEND_TYPE=LND
            LND_ADDRESS=${lndRpcClientAddress}:${toString lnd.rpcPort}
            LND_CERT_FILE=${lnd.certPath}
            LND_MACAROON_FILE=${cfg.dataDir}/admin.macaroon
          ''
        else if cfg.lnBackend == "ldk" then
          ''
            LN_BACKEND_TYPE=LDK
            ${optionalString (cfg.ldk.network != null) "LDK_NETWORK=${cfg.ldk.network}"}
            ${optionalString (cfg.ldk.esploraServer != null) "LDK_ESPLORA_SERVER=${cfg.ldk.esploraServer}"}
            ${optionalString (cfg.ldk.gossipSource != null) "LDK_GOSSIP_SOURCE=${cfg.ldk.gossipSource}"}
            ${optionalString (cfg.ldk.logLevel != null) "LDK_LOG_LEVEL=${toString cfg.ldk.logLevel}"}
            ${optionalString (cfg.ldk.vssUrl != null) "LDK_VSS_URL=${cfg.ldk.vssUrl}"}
            ${optionalString (
              cfg.ldk.listeningAddresses != null
            ) "LDK_LISTENING_ADDRESSES=${cfg.ldk.listeningAddresses}"}
            ${optionalString (
              cfg.ldk.transientNetworkGraph != null
            ) "LDK_TRANSIENT_NETWORK_GRAPH=${boolToString cfg.ldk.transientNetworkGraph}"}
          ''
        else if cfg.lnBackend == "phoenix" then
          ''
            LN_BACKEND_TYPE=PHOENIX
            ${optionalString (cfg.phoenix.address != null) "PHOENIXD_ADDRESS=${cfg.phoenix.address}"}
          ''
        else
          "";
    in
    ''
      WORK_DIR=${cfg.dataDir}
      DATABASE_URI=${cfg.dataDir}/nwc.db
      PORT=${toString cfg.port}
      LOG_LEVEL=${toString cfg.logLevel}
      AUTO_LINK_ALBY_ACCOUNT=${boolToString cfg.autoLinkAlbyAccount}
      ${optionalString (cfg.logToFile != null) "LOG_TO_FILE=${boolToString cfg.logToFile}"}
      ${optionalString (cfg.logDBQueries != null) "LOG_DB_QUERIES=${boolToString cfg.logDBQueries}"}
      ${optionalString (cfg.network != null) "NETWORK=${cfg.network}"}
      ${optionalString (cfg.mempoolApi != null) "MEMPOOL_API=${cfg.mempoolApi}"}
      ${optionalString (cfg.albyOAuth.clientId != null) "ALBY_OAUTH_CLIENT_ID=${cfg.albyOAuth.clientId}"}
      ${optionalString (cfg.baseUrl != null) "BASE_URL=${cfg.baseUrl}"}
      ${optionalString (cfg.frontendUrl != null) "FRONTEND_URL=${cfg.frontendUrl}"}
      ${optionalString (cfg.logEvents != null) "LOG_EVENTS=${boolToString cfg.logEvents}"}
      ${optionalString (cfg.relay != null) "RELAY=${cfg.relay}"}
      ${optionalString (cfg.boltzApi != null) "BOLTZ_API=${cfg.boltzApi}"}
      ${optionalString (
        cfg.enableAdvancedSetup != null
      ) "ENABLE_ADVANCED_SETUP=${boolToString cfg.enableAdvancedSetup}"}
      ${backendOpts}
      ${optionalString (cfg.extraConfig != null) cfg.extraConfig}
    '';

  # Persisted env file that contains secrets
  envFile = "${cfg.dataDir}/.env";

in
{
  options.services.albyhub = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Alby Hub, a service to control lightning wallets over nostr.
        See the user guide at https://guides.getalby.com/user-guide/alby-hub.
      '';
    };

    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.albyhub;
      defaultText = "config.nix-bitcoin.pkgs.albyhub";
      description = "The albyhub package to use.";
    };

    user = mkOption {
      type = types.str;
      default = "albyhub";
      description = "The user as which to run Alby Hub.";
    };

    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run Alby Hub.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/albyhub";
      description = "The data directory for Alby Hub.";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "This option does nothing. It is only present only to satisfy the onion service module requirements.";
    };

    port = mkOption {
      type = types.port;
      default = 8082;
      description = "The port for Alby Hub to listen on.";
    };

    relay = mkOption {
      type = with types; nullOr (either str (listOf str));
      example = [ "wss://relay.damus.io" "wss://offchain.pub" "wss://relay.primal.net" ];
      default = if cfg.tor.proxy then torRelays else null;
      apply = value: if builtins.isList value then concatStringsSep "," value else value;
      description = ''
        The default nostr relays to use. Find more relays:
        - https://nostrwat.ch/
        - https://github.com/0xtrr/onion-service-nostr-relays
      '';
    };

    logLevel = mkOption {
      type = types.int;
      default = 4;
      description = "Log level for the application. Higher is more verbose.";
    };

    logToFile = mkOption {
      type = with types; nullOr bool;
      default = null;
      description = "Log to file.";
    };

    logDBQueries = mkOption {
      type = with types; nullOr bool;
      default = null;
      description = "Log database queries.";
    };

    network = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "The network to use (e.g. mainnet, testnet, regtest).";
      example = "signet";
    };

    mempoolApi = mkOption {
      type = with types; nullOr str;
      default =
        if config.services.mempool.enable then
          "http://${nbLib.addressWithPort config.services.mempool.address config.services.mempool.port}/api"
        else
          null;
      description = "Mempool API endpoint.";
      example = "https://mempool.space/api";
    };

    baseUrl = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        Public base URL of your Alby Hub backend (used as `BASE_URL`).
        This must be reachable by the browser and is required when using a custom Alby OAuth client,
        because the OAuth callback is `${baseUrl}/api/alby/callback`.
      '';
      example = "http://localhost:8082";
    };

    frontendUrl = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        Public URL of the Hub frontend UI used for browser redirects (for example after OAuth or logout).
        If unset, redirects fall back to `baseUrl`.
      '';
    };

    logEvents = mkOption {
      type = with types; nullOr bool;
      default = null;
      description = "Log events.";
    };

    autoLinkAlbyAccount = mkOption {
      type = types.bool;
      default = false;
      description = "Auto link Alby account.";
    };

    enableAdvancedSetup = mkOption {
      type = with types; nullOr bool;
      default = null;
      description = "Enable advanced setup.";
    };

    boltzApi = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "wss://api.boltz.exchange/";
      description = "Boltz API endpoint.";
    };

    extraConfig = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Extra configuration options appended to the environment file.";
    };

    autoUnlockPasswordFile = mkOption {
      type = with types; nullOr path;
      default = null;
      description = ''
        Path to a file containing the password to auto-unlock Alby Hub on startup.
        Password will still be required to access the interface.
        Setting this option is insecure. The password file will be world-readable
        in the Nix store.
      '';
    };

    jwtSecretFile = mkOption {
      type = with types; nullOr path;
      default = null;
      description = ''
        Path to a file containing the JWT secret.
        Setting this option is insecure. The secret file will be world-readable
        in the Nix store.
      '';
    };

    lnBackend = mkOption {
      type =
        with types;
        nullOr (enum [
          "lnd"
          "ldk"
          "phoenix"
        ]);
      default = null;
      description = ''
        The lightning backend to use.
        - `lnd`: Use the LND backend.
        - `ldk`: Use the built-in LDK backend.
        - `phoenix`: Use a phoenixd backend.
      '';
    };

    ldk = {
      network = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "The LDK network to use.";
      };
      esploraServer = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "LDK Esplora Server URL.";
      };
      gossipSource = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "LDK Gossip Source.";
      };
      vssUrl = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "LDK VSS URL.";
      };
      listeningAddresses = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "LDK Listening Addresses.";
      };
      transientNetworkGraph = mkOption {
        type = with types; nullOr bool;
        default = null;
        description = "LDK Transient Network Graph.";
      };
      logLevel = mkOption {
        type = with types; nullOr int;
        default = null;
        description = "LDK debug log level to get more info.";
      };
    };

    albyOAuth = {
      clientId = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Alby OAuth Client ID.";
      };
      clientSecretFile = mkOption {
        type = with types; nullOr path;
        default = null;
        description = ''
          Path to a file containing the Alby OAuth client secret.
        '';
      };
    };

    phoenix = {
      address = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Phoenixd address.";
      };
      authorizationFile = mkOption {
        type = with types; nullOr path;
        default = null;
        description = "Path to a file containing the Phoenixd authorization.";
      };
    };

    tor = nbLib.tor;

    httpProxyPort = mkOption {
      type = types.port;
      default = 8118;
      description = ''
        Local Tor HTTP CONNECT proxy port used for `HTTP_PROXY`/`HTTPS_PROXY`
        when `services.albyhub.tor.proxy` is enabled.
      '';
    };

    getPublicAddressCmd = mkOption {
      type = types.str;
      default = "";
      description = ''
        Bash expression which outputs the public service address.
        If left empty, no address is announced.
      '';
    };
  };

  config = mkMerge [
    # If lnd is enabled, use it as the albyhub backend
    (mkIf config.services.lnd.enable {
      services.albyhub.lnBackend = mkDefault "lnd";
    })
    (mkIf cfg.enable {

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
      };
      users.groups.${cfg.group} = { };

      # Ensure Tor SOCKS client is available when proxying
      services.tor = mkIf cfg.tor.proxy {
        enable = true;
        client.enable = true;
        # Provide an HTTP CONNECT proxy via Tor so HTTP(S)/WS clients can use it
        settings.HTTPTunnelPort = [ { addr = "127.0.0.1"; port = cfg.httpProxyPort; } ];
      };

      systemd.tmpfiles.rules = [
        "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      ];

      systemd.services.albyhub = {
        description = mkDefault "Alby Hub";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
        ]
        ++ optional (cfg.lnBackend == "lnd") "lnd.service"
        ++ optional cfg.tor.proxy "tor.service";

        environment = mkIf cfg.tor.proxy {
          HTTP_PROXY = "http://127.0.0.1:${toString cfg.httpProxyPort}";
          HTTPS_PROXY = "http://127.0.0.1:${toString cfg.httpProxyPort}";
          # Use Tor SOCKS for generic proxy-aware clients.
          ALL_PROXY = "socks5h://${config.nix-bitcoin.torClientAddressWithPort}";
          NO_PROXY = "127.0.0.1,localhost,::1";
        };

        serviceConfig =
          nbLib.defaultHardening
          // {
            # Build `${envFile}` at service start so dynamic values and secrets are resolved at runtime,
            # rather than being baked into the Nix-evaluated config. This hook also handles privileged
            # setup (for example copying LND macaroon and fixing ownership/permissions) before dropping to `${cfg.user}`.
            ExecStartPre =
              let
                catSecret = secret: optionalString (secret != null) "cat ${secret}";
                appendToFile =
                  key: secret:
                  optionalString (secret != null) ''
                    echo -n '${key}=' >> ${envFile}
                    ${catSecret secret} >> ${envFile}
                    echo >> ${envFile}
                  '';
              in
              [
                (nbLib.rootScript "albyhub-setup" ''
                  ${optionalString (cfg.lnBackend == "lnd") ''
                    install -m640 -o ${cfg.user} -g ${cfg.group} -D ${lnd.networkDir}/admin.macaroon ${cfg.dataDir}/admin.macaroon
                  ''}
                  # Create env file without secrets
                  cat > ${envFile} <<EOF
                  ${envFileContent}
                  EOF
                  ${optionalString (cfg.frontendUrl == null && cfg.getPublicAddressCmd != "") ''
                    echo "FRONTEND_URL=http://$(${cfg.getPublicAddressCmd})" >> ${envFile}
                  ''}
                  # Append secrets
                  ${appendToFile "AUTO_UNLOCK_PASSWORD" cfg.autoUnlockPasswordFile}
                  ${optionalString (cfg.jwtSecretFile != null) (appendToFile "JWT_SECRET" cfg.jwtSecretFile)}
                  ${optionalString (cfg.albyOAuth.clientSecretFile != null) (
                    appendToFile "ALBY_OAUTH_CLIENT_SECRET" cfg.albyOAuth.clientSecretFile
                  )}
                  ${optionalString (cfg.phoenix.authorizationFile != null) (
                    appendToFile "PHOENIXD_AUTHORIZATION" cfg.phoenix.authorizationFile
                  )}

                  chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
                  chmod 600 ${envFile}
                '')
              ];

            User = cfg.user;
            Group = cfg.group;
            ExecStart = "${cfg.package}/bin/albyhub";
            EnvironmentFile = "-${envFile}";
            WorkingDirectory = cfg.dataDir;
            Restart = "on-failure";
            RestartSec = "10s";
            ReadWritePaths = [ cfg.dataDir ];
          }
          // nbLib.allowedIPAddresses cfg.tor.enforce;

      };

    })
  ];
}
