set -e
set -o pipefail

OUTFILE=/var/lib/nodeinfo.nix

BITCOIND_ONION=$(cat /var/lib/tor/onion/bitcoind/hostname)
CLIGHTNING_ID=$(sudo -u clightning lightning-cli getinfo | jq -r '.id')

rm -f $OUTFILE
{
    echo \{
    echo "  bitcoind_onion = \"$BITCOIND_ONION\";"
    echo "  clightning_id = \"$CLIGHTNING_ID\";"
    echo \}
} > $OUTFILE
