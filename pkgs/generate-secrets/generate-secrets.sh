#!/usr/bin/env bash

set -euo pipefail

opensslConf=${1:-openssl.cnf}

makePasswordSecret() {
    # Passwords have alphabet {a-z, A-Z, 0-9} and ~119 bits of entropy
    [[ -e $1 ]] || pwgen -s 20 1 > "$1"
}
makeHMAC() {
    user=$1
    rpcauth $user $(cat bitcoin-rpcpassword-$user) | grep rpcauth | cut -d ':' -f 2 > bitcoin-HMAC-$user
}

makePasswordSecret bitcoin-rpcpassword-privileged
makePasswordSecret bitcoin-rpcpassword-btcpayserver
makePasswordSecret bitcoin-rpcpassword-joinmarket-ob-watcher
makePasswordSecret bitcoin-rpcpassword-public
makePasswordSecret lnd-wallet-password
makePasswordSecret liquid-rpcpassword
makePasswordSecret spark-wallet-password
makePasswordSecret backup-encryption-password
makePasswordSecret jm-wallet-password

[[ -e bitcoin-HMAC-privileged ]] || makeHMAC privileged
[[ -e bitcoin-HMAC-public ]] || makeHMAC public
[[ -e bitcoin-HMAC-btcpayserver ]] || makeHMAC btcpayserver
[[ -e bitcoin-HMAC-joinmarket-ob-watcher ]] || makeHMAC joinmarket-ob-watcher
[[ -e spark-wallet-login   ]] || echo "login=spark-wallet:$(cat spark-wallet-password)" > spark-wallet-login
[[ -e backup-encryption-env ]] || echo "PASSPHRASE=$(cat backup-encryption-password)" > backup-encryption-env

makeCert() {
  if [[ ! -e $name-key || ! -e $name-cert ]]; then
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
      -sha256 -days 3650 -nodes -keyout "$name-key" -out "$name-cert" \
      -subj "/CN=localhost/O=$name" \
      -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:169.254.1.14,IP:169.254.1.22"
    # TODO: Remove hardcoded lnd, loopd netns ips
  fi
}

makeCert lnd
makeCert loop
