set -e
set -o pipefail

BITCOIND_ONION="$(cat /var/lib/onion-chef/operator/bitcoind)"
echo BITCOIND_ONION="$BITCOIND_ONION"

if [ -x "$(command -v lightning-cli)" ]; then
    CLIGHTNING_NODEID=$(lightning-cli getinfo | jq -r '.id')
    CLIGHTNING_ONION="$(cat /var/lib/onion-chef/operator/clightning)"
    CLIGHTNING_ID="$CLIGHTNING_NODEID@$CLIGHTNING_ONION:9735"
    echo CLIGHTNING_NODEID="$CLIGHTNING_NODEID"
    echo CLIGHTNING_ONION="$CLIGHTNING_ONION"
    echo CLIGHTNING_ID="$CLIGHTNING_ID"
fi

if [ -x "$(command -v lncli)" ]; then
    LND_NODEID=$(sudo -u lnd lncli --tlscertpath /secrets/lnd_cert --macaroonpath /var/lib/lnd/chain/bitcoin/mainnet/admin.macaroon getinfo | jq -r '.uris[0]')
    echo LND_NODEID="$LND_NODEID"
fi

NGINX_ONION_FILE=/var/lib/onion-chef/operator/nginx
if [ -e "$NGINX_ONION_FILE" ]; then
    NGINX_ONION="$(cat $NGINX_ONION_FILE)"
    echo NGINX_ONION="$NGINX_ONION"
fi

LIQUIDD_ONION_FILE=/var/lib/onion-chef/operator/liquidd
if [ -e "$LIQUIDD_ONION_FILE" ]; then
    LIQUIDD_ONION="$(cat $LIQUIDD_ONION_FILE)"
    echo LIQUIDD_ONION="$LIQUIDD_ONION"
fi

SPARKWALLET_ONION_FILE=/var/lib/onion-chef/operator/spark-wallet
if [ -e "$SPARKWALLET_ONION_FILE" ]; then
    SPARKWALLET_ONION="$(cat $SPARKWALLET_ONION_FILE)"
    echo SPARKWALLET_ONION="http://$SPARKWALLET_ONION"
fi

ELECTRS_ONION_FILE=/var/lib/onion-chef/operator/electrs
if [ -e "$ELECTRS_ONION_FILE" ]; then
    ELECTRS_ONION="$(cat $ELECTRS_ONION_FILE)"
    echo ELECTRS_ONION="$ELECTRS_ONION"
fi

SSHD_ONION_FILE=/var/lib/onion-chef/operator/sshd
if [ -e "$SSHD_ONION_FILE" ]; then
    SSHD_ONION="$(cat $SSHD_ONION_FILE)"
    echo SSHD_ONION="$SSHD_ONION"
fi
