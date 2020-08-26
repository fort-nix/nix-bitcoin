{ config, lib, pkgs, ... }:

with lib;

let
  operatorName = config.nix-bitcoin.operatorName;
  script = pkgs.writeScriptBin "nodeinfo" ''
    set -eo pipefail

    BITCOIND_ONION="$(cat /var/lib/onion-chef/${operatorName}/bitcoind)"
    echo BITCOIND_ONION="$BITCOIND_ONION"

    if systemctl is-active --quiet clightning; then
      CLIGHTNING_NODEID=$(lightning-cli getinfo | jq -r '.id')
      CLIGHTNING_ONION="$(cat /var/lib/onion-chef/${operatorName}/clightning)"
      CLIGHTNING_ID="$CLIGHTNING_NODEID@$CLIGHTNING_ONION:9735"
      echo CLIGHTNING_NODEID="$CLIGHTNING_NODEID"
      echo CLIGHTNING_ONION="$CLIGHTNING_ONION"
      echo CLIGHTNING_ID="$CLIGHTNING_ID"
    fi

    if systemctl is-active --quiet lnd; then
      LND_NODEID=$(lncli getinfo | jq -r '.uris[0]')
      echo LND_NODEID="$LND_NODEID"
    fi

    NGINX_ONION_FILE=/var/lib/onion-chef/${operatorName}/nginx
    if [ -e "$NGINX_ONION_FILE" ]; then
      NGINX_ONION="$(cat $NGINX_ONION_FILE)"
      echo NGINX_ONION="$NGINX_ONION"
    fi

    LIQUIDD_ONION_FILE=/var/lib/onion-chef/${operatorName}/liquidd
    if [ -e "$LIQUIDD_ONION_FILE" ]; then
      LIQUIDD_ONION="$(cat $LIQUIDD_ONION_FILE)"
      echo LIQUIDD_ONION="$LIQUIDD_ONION"
    fi

    SPARKWALLET_ONION_FILE=/var/lib/onion-chef/${operatorName}/spark-wallet
    if [ -e "$SPARKWALLET_ONION_FILE" ]; then
      SPARKWALLET_ONION="$(cat $SPARKWALLET_ONION_FILE)"
      echo SPARKWALLET_ONION="http://$SPARKWALLET_ONION"
    fi

    ELECTRS_ONION_FILE=/var/lib/onion-chef/${operatorName}/electrs
    if [ -e "$ELECTRS_ONION_FILE" ]; then
      ELECTRS_ONION="$(cat $ELECTRS_ONION_FILE)"
      echo ELECTRS_ONION="$ELECTRS_ONION"
    fi

    BTCPAYSERVER_ONION_FILE=/var/lib/onion-chef/${operatorName}/btcpayserver
    if [ -e "$BTCPAYSERVER_ONION_FILE" ]; then
      BTCPAYSERVER_ONION="$(cat $BTCPAYSERVER_ONION_FILE)"
      echo BTCPAYSERVER_ONION="$BTCPAYSERVER_ONION"
    fi

    SSHD_ONION_FILE=/var/lib/onion-chef/${operatorName}/sshd
    if [ -e "$SSHD_ONION_FILE" ]; then
    SSHD_ONION="$(cat $SSHD_ONION_FILE)"
    echo SSHD_ONION="$SSHD_ONION"
    fi
  '';
in {
  options = {
    programs.nodeinfo = mkOption {
      readOnly = true;
      default = script;
    };
  };

  config = {
    environment.systemPackages = [ script ];
  };
}
