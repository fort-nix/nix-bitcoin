{ config, lib, pkgs, ... }:

with lib;
let
  options.services.monit-nb = {
    enable = mkEnableOption "nix-bitcoin monitoring via monit";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Dovecot server address.";
    };
    port = mkOption {
      type = types.port;
      default = 143;
      description = "Dovecot server port.";
    };
  };

  cfg = config.services.monit-nb;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;

  checkStatus = pkgs.writeScriptBin "checkStatus" ''
    #! /bin/sh
    if [[ $(systemctl show --property=ActiveState $1) == *"=active"* ]];
      then exit 0
      else exit 1
    fi
  '';

  configFile = ''
    set alert monitmail@localhost
    set daemon 120 with start delay 60
    set mailserver
      localhost

    set httpd unixsocket /var/run/monit.sock
      uid root
      gid root
      permission 660
      # Placeholder username & password
      # Secured through unix socket permissions
      allow admin:obwjoawijerfoijsiwfj29jf2f2jd

    check filesystem root with path /
      if space usage > 80% then alert
      if inode usage > 80% then alert

    check system $HOST
      if cpu usage > 95% for 10 cycles then alert
      if memory usage > 75% for 5 cycles then alert
      if swap usage > 20% for 10 cycles then alert
      if loadavg (1min) > 90 for 15 cycles then alert
      if loadavg (5min) > 80 for 10 cycles then alert
      if loadavg (15min) > 70 for 8 cycles then alert

    check program duplicity path "${pkgs.systemd}/bin/systemctl is-failed duplicity"
      if changed status then alert

    check program bitcoind path "${checkStatus}/bin/checkStatus bitcoind"
      if changed status then alert

    check program bitcoind-import-banlist path "${pkgs.systemd}/bin/systemctl is-failed bitcoind-import-banlist"
      if changed status then alert

    ${optionalString config.services.btcpayserver.enable ''
      check program nbxplorer path "${checkStatus}/bin/checkStatus nbxplorer"
        if changed status then alert
    ''}

    ${optionalString config.services.btcpayserver.enable ''
      check program btcpayserver path "${checkStatus}/bin/checkStatus nbxplorer"
        if changed status then alert
    ''}

    ${optionalString config.services.charge-lnd.enable ''
      check program charge-lnd path "${checkStatus}/bin/checkStatus charge-lnd"
        if changed status then alert
    ''}

    ${optionalString config.services.clightning.enable ''
      check program clightning path "${checkStatus}/bin/checkStatus clightning"
        if changed status then alert
    ''}

    ${optionalString config.services.electrs.enable ''
      check program electrs path "${checkStatus}/bin/checkStatus electrs"
        if changed status then alert
    ''}

    ${optionalString config.services.joinmarket.enable ''
      check program joinmarket path "${checkStatus}/bin/checkStatus joinmarket"
        if changed status then alert
    ''}

    ${optionalString config.services.joinmarket.yieldgenerator.enable ''
      check program joinmarket-yieldgenerator path "${checkStatus}/bin/checkStatus joinmarket-yieldgenerator"
        if changed status then alert
    ''}

    ${optionalString config.services.joinmarket-ob-watcher.enable ''
      check program joinmarket-ob-watcher path "${checkStatus}/bin/checkStatus joinmarket-ob-watcher"
        if changed status then alert
    ''}

    ${optionalString config.services.lightning-loop.enable ''
      check program lightning-loop path "${checkStatus}/bin/checkStatus lightning-loop"
        if changed status then alert
    ''}

    ${optionalString config.services.lightning-pool.enable ''
      check program lightning-pool path "${checkStatus}/bin/checkStatus lightning-pool"
        if changed status then alert
    ''}

    ${optionalString config.services.liquidd.enable ''
      check program liquidd path "${checkStatus}/bin/checkStatus liquidd"
        if changed status then alert
    ''}

    ${optionalString config.services.lnd.enable ''
      check program lnd path "${checkStatus}/bin/checkStatus lnd"
        if changed status then alert
    ''}

    ${optionalString config.services.clightning-rest.enable ''
      check program clightning-rest path "${checkStatus}/bin/checkStatus clightning-rest"
        if changed status then alert
    ''}

    ${optionalString config.services.rtl.enable ''
      check program rtl path "${checkStatus}/bin/checkStatus rtl"
        if changed status then alert
    ''}

    ${optionalString config.services.spark-wallet.enable ''
      check program spark-wallet path "${checkStatus}/bin/checkStatus spark-wallet"
        if changed status then alert
    ''}
  '';

in {
  inherit options;

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.monit ];

    environment.etc.monitrc = {
      text = "${configFile}";
      mode = "0400";
    };

    systemd.services.monit-nb = {
      description = "Pro-active monitoring utility for nix-bitcoin";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.monit}/bin/monit -I -c /etc/monitrc";
        ExecStop = "${pkgs.monit}/bin/monit -c /etc/monitrc quit";
        ExecReload = "${pkgs.monit}/bin/monit -c /etc/monitrc reload";
        KillMode = "process";
        Restart = "always";
      } // nbLib.allowLocalIPAddresses;
      restartTriggers = [ config.environment.etc.monitrc.source ];
    };

    services.postfix.enable = true;
    services.dovecot2.enable = true;
    users.users.monitmail = {
      passwordFile = "${secretsDir}/monitmail-password";
      isNormalUser = true;
    };

    nix-bitcoin.secrets.monitmail-password.user = "root";
    nix-bitcoin.generateSecretsCmds.monitmail = ''
      makePasswordSecret monitmail-password
    '';
  };
}

