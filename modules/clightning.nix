{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.clightning;
  inherit (config) nix-bitcoin-services;
  configFile = pkgs.writeText "config" ''
    autolisten=${if cfg.autolisten then "true" else "false"}
    network=bitcoin
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}
    always-use-proxy=${if cfg.always-use-proxy then "true" else "false"}
    ${optionalString (cfg.bind-addr != null) "bind-addr=${cfg.bind-addr}"}
    bitcoin-rpcuser=${cfg.bitcoin-rpcuser}
  '';
in {
  options.services.clightning = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the clightning service will be installed.
      '';
    };
    autolisten = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the clightning service will listen.
      '';
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Set a socks proxy to use to connect to Tor nodes (or for all connections if *always-use-proxy* is set)";
    };
    always-use-proxy = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Always use the *proxy*, even to connect to normal IP addresses (you can still connect to Unix domain sockets manually). This also disables all DNS lookups, to avoid leaking information.
      '';
    };
    bind-addr = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Set an IP address or UNIX domain socket to listen to";
    };
    bitcoin-rpcuser = mkOption {
      type = types.str;
      description = ''
        Bitcoin RPC user
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/clightning";
      description = "The data directory for clightning.";
    };
    cli = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "lightning-cli"
      # Switch user because c-lightning doesn't allow setting the permissions of the rpc socket
      # https://github.com/ElementsProject/lightning/issues/1366
      ''
        exec sudo -u clightning ${pkgs.nix-bitcoin.clightning}/bin/lightning-cli --lightning-dir='${cfg.dataDir}' "$@"
      '';
      description = "Binary to connect with the clightning instance.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    users.users.clightning = {
        description = "clightning User";
        group = "clightning";
        extraGroups = [ "bitcoinrpc" ];
        home = cfg.dataDir;
    };
    users.groups.clightning = {};

    systemd.services.clightning = {
      description = "Run clightningd";
      path  = [ pkgs.nix-bitcoin.bitcoind ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        mkdir -m 0770 -p ${cfg.dataDir}
        cp ${configFile} ${cfg.dataDir}/config
        chown -R 'clightning:clightning' '${cfg.dataDir}'
        # give group read access to allow using lightning-cli
        chmod u=rw,g=r,o= ${cfg.dataDir}/config
        # The RPC socket has to be removed otherwise we might have stale sockets
        rm -f ${cfg.dataDir}/bitcoin/lightning-rpc
        echo "bitcoin-rpcpassword=$(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword)" >> '${cfg.dataDir}/config'
        '';
      serviceConfig = {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.nix-bitcoin.clightning}/bin/lightningd --lightning-dir=${cfg.dataDir}";
        User = "clightning";
        Restart = "on-failure";
        RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening
        // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP
        );
      # Wait until the rpc socket appears
      postStart = ''
        while [[ ! -e ${cfg.dataDir}/bitcoin/lightning-rpc ]]; do
            sleep 0.1
        done
      '';
    };
  };
}
