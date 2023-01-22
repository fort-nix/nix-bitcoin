#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Test Tor and WireGuard connections on a mobile device

# 1. Run container
run-tests.sh -s wireguard-lndconnect-online container

# 2. Test connecting via Tor
# Print QR codes for lnd, clightning-rest connections via Tor
c lndconnect
c lndconnect-clightning
# Add these to Zeus >= 0.7.1.
# To explicitly check if the connection is successful, press the node logo in the top
# left corner, and then "Node Info".

# Debug
c lndconnect --url
c lndconnect-clightning --url

# 3. Test connecting via WireGuard

# 3.1 Forward WireGuard port from the container host to the container
iptables -t nat -A PREROUTING -p udp --dport 51821 -j DNAT --to-destination 10.225.255.2

# 3.2. Optional: When your container host has an external firewall,
# forward the WireGuard port to the container host:
# - Port: 51821
# - Protocol: UDP
# - Destination: IPv4 of the container host

# 3.2 Print QR code and setup wireguard on the mobile device
c nix-bitcoin-wg-connect
c nix-bitcoin-wg-connect --text

# Print QR codes for lnd, clightning-rest connections via WireGuard
c lndconnect-wg
c lndconnect-clightning-wg
# Add these to Zeus >= 0.7.1.
# To explicitly check if the connection is successful, press the node logo in the top
# left corner, and then "Node Info".

# Debug
c lndconnect-wg --url
c lndconnect-clightning-wg --url

# 3.3.remove external firewall port forward, remove local port forward:
iptables -t nat -D PREROUTING -p udp --dport 51821 -j DNAT --to-destination 10.225.255.2
# Now exit the container shell

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Debug lndconnect

run-tests.sh -s wireguard-lndconnect-online container

c nodeinfo

c lndconnect --url
c lndconnect-wg --url
c lndconnect-clightning --url
c lndconnect-clightning-wg --url

c lndconnect
c lndconnect-wg
c lndconnect-clightning
c lndconnect-clightning-wg
