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
    (mkRenamedOptionModule [ "services" "spark-wallet" "host" ] [ "services" "spark-wallet" "address" ])
    (mkRenamedOptionModule [ "services" "lnd" "rpclisten" ] [ "services" "lnd" "rpcAddress" ])
    (mkRenamedOptionModule [ "services" "lnd" "listen" ] [ "services" "lnd" "address" ])
    (mkRenamedOptionModule [ "services" "lnd" "listenPort" ] [ "services" "lnd" "port" ])
    (mkRenamedOptionModule [ "services" "btcpayserver" "bind" ] [ "services" "btcpayserver" "address" ])
    (mkRenamedOptionModule [ "services" "liquidd" "bind" ] [ "services" "liquidd" "address" ])
    (mkRenamedOptionModule [ "services" "liquidd" "rpcbind" ] [ "services" "liquidd" "rpc" "address" ])
    # 0.0.70
    (mkRenamedOptionModule [ "services" "rtl" "cl-rest" ] [ "services" "clightning-rest" ])
    (mkRenamedOptionModule [ "services" "lnd" "restOnionService" "enable" ] [ "services" "lnd" "lndconnectOnion" "enable" ])

    (mkRenamedOptionModule [ "nix-bitcoin" "setup-secrets" ] [ "nix-bitcoin" "setupSecrets" ])

    (mkRenamedAnnounceTorOption "clightning")
    (mkRenamedAnnounceTorOption "lnd")

    # 0.0.53
    (mkRemovedOptionModule [ "services" "electrs" "high-memory" ] ''
      This option is no longer supported by electrs 0.9.0. Electrs now always uses
      bitcoin peer connections for syncing blocks. This performs well on low and high
      memory systems.
    '')
  ] ++
  # 0.0.59
  (map mkSplitEnforceTorOption [
    "clightning"
    "lightning-loop"
    "lightning-pool"
    "liquid"
    "lnd"
    "spark-wallet"
    "bitcoind"
  ]) ++
  (map mkRenamedEnforceTorOption [
    "btcpayserver"
    "rtl"
    "electrs"
  ]);

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
