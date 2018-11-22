sleep 5
OUTFILE=/var/lib/nodeinfo.nix
rm -f $OUTFILE
{
    echo \{
    echo "  bitcoind_onion = \"$(cat /var/lib/tor/onion/bitcoind/hostname)\";"
    echo "  clightning_id = \"$(sudo -u clightning lightning-cli getinfo | jq -r '.id')\";"
    echo \}
} > $OUTFILE
