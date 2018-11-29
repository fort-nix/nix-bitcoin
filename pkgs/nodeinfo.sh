set -e
set -o pipefail

printenv
BITCOIND_ONION=$(cat /var/lib/tor/onion/bitcoind/hostname)
CLIGHTNING_ID=$(sudo -u clightning lightning-cli --lightning-dir=/var/lib/clightning getinfo | jq -r '.id')

echo \{
echo "  bitcoind_onion = \"$BITCOIND_ONION\";"
echo "  clightning_id = \"$CLIGHTNING_ID\";"
echo \}
