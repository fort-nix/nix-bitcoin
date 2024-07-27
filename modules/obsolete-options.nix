{ lib, config, ... }:

with lib;
let
  mkRenamedAnnounceTorOption = service:
    # use mkRemovedOptionModule because mkRenamedOptionModule fails with an infinite recursion error
    mkRemovedOptionModule [ "services" service "announce-tor" ] ''
      Use option `nix-bitcoin.onionServices.${service}.public` instead.
    '';

  mkSplitEnforceTorOption = service:
    (mkRemovedOptionModule [ "services" service "enforceTor" ] ''
      The option has been split into options `tor.proxy` and `tor.enforce`.
      Set `tor.proxy = true` to proxy outgoing connections with Tor.
      Set `tor.enforce = true` to only allow connections (incoming and outgoing) through Tor.
    '');
  mkRenamedEnforceTorOption = service:
    (mkRenamedOptionModule [ "services" service "enforceTor" ] [ "services" service "tor" "enforce" ]);

in {
  imports = [
    (mkRenamedOptionModule [ "services" "bitcoind" "bind" ] [ "services" "bitcoind" "address" ])
    (mkRenamedOptionModule [ "services" "bitcoind" "rpcallowip" ] [ "services" "bitcoind" "rpc" "allowip" ])
    (mkRenamedOptionModule [ "services" "bitcoind" "rpcthreads" ] [ "services" "bitcoind" "rpc" "threads" ])
    (mkRenamedOptionModule [ "services" "clightning" "bind-addr" ] [ "services" "clightning" "address" ])
    (mkRenamedOptionModule [ "services" "clightning" "bindport" ] [ "services" "clightning" "port" ])
    (mkRenamedOptionModule [ "services" "lnd" "rpclisten" ] [ "services" "lnd" "rpcAddress" ])
    (mkRenamedOptionModule [ "services" "lnd" "listen" ] [ "services" "lnd" "address" ])
    (mkRenamedOptionModule [ "services" "lnd" "listenPort" ] [ "services" "lnd" "port" ])
    (mkRenamedOptionModule [ "services" "btcpayserver" "bind" ] [ "services" "btcpayserver" "address" ])
    (mkRenamedOptionModule [ "services" "liquidd" "bind" ] [ "services" "liquidd" "address" ])
    (mkRenamedOptionModule [ "services" "liquidd" "rpcbind" ] [ "services" "liquidd" "rpc" "address" ])
    # 0.0.70
    (mkRenamedOptionModule [ "services" "rtl" "cl-rest" ] [ "services" "clightning-rest" ])

    (mkRenamedOptionModule [ "nix-bitcoin" "setup-secrets" ] [ "nix-bitcoin" "setupSecrets" ])

    (mkRenamedAnnounceTorOption "clightning")
    (mkRenamedAnnounceTorOption "lnd")

    # 0.0.53
    (mkRemovedOptionModule [ "services" "electrs" "high-memory" ] ''
      This option is no longer supported by electrs 0.9.0. Electrs now always uses
      bitcoin peer connections for syncing blocks. This performs well on low and high
      memory systems.
    '')
    # 0.0.86
    (mkRemovedOptionModule [ "services" "lnd" "restOnionService" "enable" ] ''
      Set the following options instead:
      services.lnd.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
    (mkRemovedOptionModule [ "services" "lnd" "lndconnectOnion" ] ''
      Set the following options instead:
      services.lnd.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
    (mkRemovedOptionModule [ "services" "clightning-rest" "lndconnectOnion" ] ''
      Set the following options instead:
      services.clightning-rest.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
  ] ++
  # 0.0.59
  (map mkSplitEnforceTorOption [
    "clightning"
    "lightning-loop"
    "lightning-pool"
    "liquid"
    "lnd"
    "bitcoind"
  ]) ++
  (map mkRenamedEnforceTorOption [
    "btcpayserver"
    "rtl"
    "electrs"
  ]) ++
  # 0.0.77
  [
    (mkRemovedOptionModule [ "services" "clightning" "plugins" "commando" ] ''
      clightning 0.12.0 ships with a reimplementation of the commando plugin
      that is incompatible with the commando module that existed in
      nix-bitcoin. The new built-in commando plugin is always enabled. For
      information on how to use it, run `lightning-cli help commando` and
      `lightning-cli help commando-rune`.
    '')
  ] ++
  # 0.0.92
  [
    (mkRemovedOptionModule [ "services" "spark-wallet" ] ''
      Spark Lightning Wallet is unmaintained and incompatible with clightning
      23.05. Therefore, the spark-wallet module has been removed from
      nix-bitcoin. For a replacement, consider using the rtl (Ride The
      Lightning) module or the clightning-rest module in combination with the
      Zeus mobile wallet.
    '')
  ]
  ++
  # 0.0.98
  [
    (mkRemovedOptionModule [ "services" "clightning" "plugins" "clboss" "acknowledgeDeprecation" ] ''
      `clboss` is maintained again and has been un-deprecated.
    '')
  ]
  ++
  # 0.0.106
  (map (plugin:
    mkRemovedOptionModule [ "services" "clightning" "plugins" plugin ] ''
      This plugin is no longer maintained.
    '')
    [ "summary" "helpme" "prometheus" ]
  )
  ++
  # 0.0.110
  [
    (mkRemovedOptionModule [ "services" "joinmarket" "yieldgenerator" "txfee" ] ''
      Option `txfee` has been removed in joinmarket 0.9.3:
      https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/v0.9.3/docs/release-notes/release-notes-0.9.3.md
    '')
  ];

  config = {
    # Migrate old clightning-rest datadir from nix-bitcoin versions < 0.0.70
    systemd.services.clightning-rest-migrate-datadir = let
      inherit (config.services) clightning-rest clightning;
    in mkIf config.services.clightning-rest.enable {
      requiredBy = [ "clightning-rest.service" ];
      before = [ "clightning-rest.service" ];
      script = ''
        if [[ -e /var/lib/cl-rest/certs ]]; then
          mv /var/lib/cl-rest/* '${clightning-rest.dataDir}'
          chown -R ${clightning.user}: '${clightning-rest.dataDir}'
          rm -r /var/lib/cl-rest
        fi
      '';
      serviceConfig.Type = "oneshot";
    };
  };
}
