# shellcheck disable=SC2086,SC2154

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Run tests
# See ../test/README.md for a tutorial
# and ../test/run-tests.sh for a complete documentation

# Start a shell in a container
run-tests.sh -s electrs container

# Run a command in a container.
# The container is deleted afterwards.
run-tests.sh -s electrs container --run c journalctl -u electrs

# Run a bash command
run-tests.sh -s bitcoind container --run c bash -c "sleep 1; journalctl -u bitcoind"

run-tests.sh -s '{
  imports = [ scenarios.regtestBase ];
  services.electrs.enable = true;
}' container --run c journalctl -u electrs

run-tests.sh -s "{
  services.electrs.enable = true;
  nix-bitcoin.nodeinfo.enable = true;
}" container --run c nodeinfo

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Get generic node infos

# Start container shell
run-tests.sh -s bitcoind container

# Run commands inside the shell:

# The node's services
c systemctl status

# Failed units
c systemctl list-units --failed

# Analyze container boot performance
c systemd-analyze critical-chain

# Listening TCP sockets
c netstat -nltp
# Listening sockets
c netstat -nlp

# The container root filesystem
ls -al /var/lib/nixos-containers/nb-test

# The container root filesystem on NixOS systems with stateVersion < 22.05
ls -al /var/lib/containers/nb-test

# Start a shell in the context of a service process.
# Must be run inside the container (enter with cmd `c`).
enter_service() {
    name=$1
    pid=$(systemctl show -p MainPID --value "$name")
    IFS=- read -r uid gid  < <(stat -c "%u-%g" "/proc/$pid")
    nsenter --all -t "$pid" --setuid "$uid" --setgid "$gid" bash
}
enter_service clightning

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# bitcoind
run-tests.sh -s bitcoind container

c systemctl status bitcoind
c systemctl cat bitcoind
c journalctl --output=short-precise -u bitcoind
ls -al /var/lib/nixos-containers/nb-test/var/lib/bitcoind
c bitcoin-cli getpeerinfo
c bitcoin-cli getnetworkinfo
c bitcoin-cli getblockchaininfo

run-tests.sh -s '{
  imports = [ scenarios.regtestBase ];
  services.bitcoind.enable = true;
}' container

address=$(c bitcoin-cli getnewaddress)
echo $address
c bitcoin-cli generatetoaddress 10 $address

# Run bitcoind with network access
run-tests.sh -s "{
  test.container.enableWAN = true;
  services.bitcoind.enable = true;
}" container --run c journalctl -u bitcoind -f

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# clightning
run-tests.sh -s clightning container

c systemctl status clightning
c journalctl --output=short-precise -u clightning
c lightning-cli getinfo

# Plugins
run-tests.sh -s "{
  services.clightning.enable = true;
  test.features.clightningPlugins = true;
}" container

c lightning-cli plugin list

# Show plugin config
nix eval --raw .#makeTest --apply '
  makeTest: let
   config = (makeTest {
      config = {
        services.clightning.enable = true;
        test.features.clightningPlugins = true;
      };
    }).nodes.machine;
  in
    config.services.clightning.extraConfig
'

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# clightning-rest
run-tests.sh -s clightning-rest container

c systemctl status clightning-rest
c journalctl -u clightning-rest
c systemctl status clightning-rest-migrate-datadir

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# electrs

run-tests.sh -s "{
  imports = [ scenarios.regtestBase ];
  services.electrs.enable = true;
}" container

c systemctl status electrs
c systemctl cat electrs
c journalctl --output=short-precise -u electrs

electrs_rpc() {
  echo "$1" | c nc 127.0.0.1 50001 | head -1 | jq
}
electrs_rpc '{"method": "server.version", "id": 0, "params": ["electrum/3.3.8", "1.4"]}'
electrs_rpc '{"method": "blockchain.headers.subscribe", "id": 0}'

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# fulcrum

run-tests.sh -s "{
  imports = [ scenarios.regtestBase ];
  services.fulcrum.enable = true;
}" container

c systemctl status fulcrum
c systemctl cat fulcrum
c journalctl --output=short-precise -u fulcrum

fulcrum_rpc() {
    echo "$1" | c nc 127.0.0.1 50002 | head -1 | jq
}
fulcrum_rpc '{"method": "server.version", "id": 0, "params": ["electrum/3.3.8", "1.4"]}'
fulcrum_rpc '{"method": "blockchain.headers.subscribe", "id": 0}'

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# lnd
run-tests.sh -s lnd container
c systemctl status lnd
c journalctl -u lnd
c lncli getinfo

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# lightning-loop
run-tests.sh -s lightning-loop container
c systemctl status lightning-loop
c journalctl -u lightning-loop

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# btcpayserver
# https://docs.btcpayserver.org/Development/GreenFieldExample/

run-tests.sh -s btcpayserver-regtest container

c systemctl status btcpayserver
c journalctl -u btcpayserver
c systemctl cat btcpayserver

c systemctl status nbxplorer
c journalctl -u nbxplorer

## Access the API
request() {
    local type=$1
    local method=$2
    local body=$3
    shift; shift; shift
    curl -sSL -H "Content-Type: application/json" -X $type --user "a@a.a:aaaaaa" \
         -d "$body" "$@" "$ip:23000/api/v1/$method" | jq
}
post() {
    local method=$1
    local body=$2
    shift; shift
    request post "$method" "$body" "$@"
}
get() {
    local method=$1
    request get "$method"
}

# Create new user
post users '{"email": "a@a.a", "password": "aaaaaa", "isAdministrator": true}'

# Login with:
# user: a@a.a
# password: aaaaaa
runuser -u "$(logname)" -- xdg-open http://$ip:23000

# create store
post stores '{"name": "a", "defaultPaymentMethod": "BTC_LightningNetwork"}'
post stores '{"name": "a", "defaultPaymentMethod": "BTC"}'

store=$(get stores | jq -r .[].id)
echo $store
get stores/$store
get stores/$store/payment-methods
get stores/$store/payment-methods/LightningNetwork

# Connect to internal lightning node (internal API, doesn't work)
# Lightning must be manually setup via the webinterface.
post stores/$store/lightning/BTC/setup "" --data-raw 'LightningNodeType=Internal&ConnectionString=&command=save'

nix run --inputs-from . nixpkgs#lynx -- --dump http://$ip:23000/embed/$store/BTC/ln

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# liquid
run-tests.sh -s liquid container

c systemctl status liquidd
c elements-cli getpeerinfo
c elements-cli getnetworkinfo
c liquidswap-cli --help

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# tor
run-tests.sh container

c cat /var/lib/tor/state
c ls -al /var/lib/tor/onion/
c ls -al /var/lib/tor/onion/bitcoind
c ls -al /var/lib/tor/onion/clightning-rest

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# joinmarket
run-tests.sh -s joinmarket container

c systemctl status joinmarket
c journalctl -u joinmarket

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# joinmarket-ob-watcher

# This starts a container with WAN access, so that jm-ob-watcher
# can connect to the joinmarket IRC servers over Tor
run-tests.sh -s jm-ob-watcher container

c systemctl status joinmarket-ob-watcher
c journalctl -u joinmarket-ob-watcher

# Manually wait for string 'started http server, visit http://127.0.0.1:62601/'
# This can take >10 minutes when the Tor network is under heavy load.
# While connecting, errors like `We failed to connect and handshake with ANY directories...`
# may be shown.
c journalctl -f -u joinmarket-ob-watcher

# Check webinterface
c curl localhost:62601
nix run --inputs-from . nixpkgs#lynx -- --dump $ip:62601
c curl -s localhost:62601 | grep -i "orders found"

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# rtl
# see ./topics/rtl.sh
