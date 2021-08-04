{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.joinmarket-ob-watcher;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;

  socks5Settings = with config.services.tor.client.socksListenAddress; ''
    socks5 = true
    socks5_host = ${addr}
    socks5_port = ${toString port}
  '';

  configFile = builtins.toFile "config" ''
    [BLOCKCHAIN]
    blockchain_source = no-blockchain

    [MESSAGING:server1]
    host = darkirc6tqgpnwd3blln3yfv5ckl47eg7llfxkmtovrv7c7iwohhb6ad.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    ${socks5Settings}

    [MESSAGING:server2]
    host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
    channel = joinmarket-pit
    port = 6667
    usessl = false
    ${socks5Settings}
  '';
in {
  options.services.joinmarket-ob-watcher = {
    enable = mkEnableOption "JoinMarket orderbook watcher";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 62601;
      description = "HTTP server port.";
    };
    dataDir = mkOption {
      readOnly = true;
      default = "/var/lib/joinmarket-ob-watcher";
      description = "The data directory for JoinMarket orderbook watcher.";
    };
    # This option is only used by netns-isolation
    enforceTor = mkOption {
      readOnly = true;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    # Joinmarket is Tor-only
    services.tor = {
      enable = true;
      client.enable = true;
    };

    systemd.services.joinmarket-ob-watcher = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "tor.service" ];
      after = [ "tor.service" ];
      # The service writes to HOME/.config/matplotlib
      environment.HOME = cfg.dataDir;
      preStart = ''
        ln -snf ${configFile} ${cfg.dataDir}/joinmarket.cfg
      '';
      serviceConfig = nbLib.defaultHardening // rec {
        DynamicUser = true;
        StateDirectory = "joinmarket-ob-watcher";
        StateDirectoryMode = "0770";
        WorkingDirectory = cfg.dataDir; # The service creates dir 'logs' in the working dir
        ExecStart = ''
          ${nbPkgs.joinmarket}/bin/ob-watcher --datadir=${cfg.dataDir} \
            --host=${cfg.address} --port=${toString cfg.port}
        '';
        SystemCallFilter = nbLib.defaultHardening.SystemCallFilter ++ [ "mbind" ] ;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowTor;
    };
  };
}
