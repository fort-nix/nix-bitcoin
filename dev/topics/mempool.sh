# Start mempool container
run-tests.sh -s mempool-regtest container

c systemctl status mempool
c systemctl status mysql
c nodeinfo

# Check backend
c curl -fsS localhost:8999/api/v1/blocks/1 | jq
c curl -fsS localhost:8999/api/v1/blocks/tip/height | jq
c curl -fsS localhost:8999/api/v1/address/1CGG9qVq2P6F7fo6sZExvNq99Jv2GDpaLE | jq

# Check frontend
c curl -fsS localhost:60845
c curl -fsS localhost:60845/api/mempool | jq
c curl -fsS localhost:60845/api/blocks/1 | jq
c curl -fsS localhost:60845/api/v1/blocks/1 | jq
c curl -fsS localhost:60845/api/blocks/tip/height | jq

# Open frontend
# shellcheck disable=SC2154
runuser -u "$(logname)" -- xdg-open "http://$ip:60845/"
