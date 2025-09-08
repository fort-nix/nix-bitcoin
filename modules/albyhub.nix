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
      ${optionalString (cfg.relay != null) "RELAY=${cfg.relay}"}
      ${optionalString (cfg.logToFile != null) "LOG_TO_FILE=${boolToString cfg.logToFile}"}
      ${optionalString (cfg.logDBQueries != null) "LOG_DB_QUERIES=${boolToString cfg.logDBQueries}"}
      ${optionalString (cfg.network != null) "NETWORK=${cfg.network}"}
      ${optionalString (cfg.mempoolApi != null) "MEMPOOL_API=${cfg.mempoolApi}"}
      ${optionalString (cfg.albyOAuth.clientId != null) "ALBY_OAUTH_CLIENT_ID=${cfg.albyOAuth.clientId}"}
      ${optionalString (cfg.baseUrl != null) "BASE_URL=${cfg.baseUrl}"}
      ${optionalString (cfg.frontendUrl != null) "FRONTEND_URL=${cfg.frontendUrl}"}
      ${optionalString (cfg.logEvents != null) "LOG_EVENTS=${boolToString cfg.logEvents}"}
      ${optionalString (
        cfg.enableAdvancedSetup != null
      ) "ENABLE_ADVANCED_SETUP=${boolToString cfg.enableAdvancedSetup}"}
      ${optionalString (cfg.boltzApi != null) "BOLTZ_API=${cfg.boltzApi}"}
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
      type = with types; nullOr str;
      default = null;
      description = "The default nostr relay.";
      example = "wss://relay.getalby.com/v1";
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
          "http://${nbLib.addressWithPort config.services.mempool.address config.services.mempool.port}"
        else
          null;
      description = "Mempool API endpoint.";
      example = "https://mempool.space/api";
    };

    baseUrl = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Base URL for the Alby Hub. Required if you want to connect to your Alby account.";
      example = "http://localhost:8082";
    };

    frontendUrl = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Frontend URL for the Alby Hub";
      example = "http://127.0.0.1:8082";
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
        ++ optional config.services.mempool.enable "mempool.service";

        serviceConfig =
          nbLib.defaultHardening
          // {
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

        # albyhub has no native tor support
        environment = mkIf (cfg.tor.proxy) (
          let
            proxy = config.nix-bitcoin.torClientAddressWithPort;
            socks5 = "socks5://${proxy}";
          in
          {
            # TODO: if this works at all, remove the ones we don't need
            ALL_PROXY = socks5;
            HTTP_PROXY = socks5;
            HTTPS_PROXY = socks5;
            all_proxy = socks5;
            http_proxy = socks5;
            https_proxy = socks5;
            NO_PROXY = "127.0.0.1,::1,localhost";
            no_proxy = "127.0.0.1,::1,localhost";
          }
        );
      };

    })
  ];
}
