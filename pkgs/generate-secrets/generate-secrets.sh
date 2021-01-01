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
makePasswordSecret bitcoin-rpcpassword-public
makePasswordSecret lnd-wallet-password
makePasswordSecret liquid-rpcpassword
makePasswordSecret spark-wallet-password
makePasswordSecret backup-encryption-password
makePasswordSecret jm-wallet-password

[[ -e bitcoin-HMAC-privileged ]] || makeHMAC privileged
[[ -e bitcoin-HMAC-public ]] || makeHMAC public
[[ -e bitcoin-HMAC-btcpayserver ]] || makeHMAC btcpayserver
[[ -e spark-wallet-login   ]] || echo "login=spark-wallet:$(cat spark-wallet-password)" > spark-wallet-login
[[ -e backup-encryption-env ]] || echo "PASSPHRASE=$(cat backup-encryption-password)" > backup-encryption-env

if [[ ! -e lnd-key || ! -e lnd-cert ]]; then
    openssl ecparam -genkey -name prime256v1 -out lnd-key
    openssl req -config $opensslConf -new -sha256 -key lnd-key -out lnd.csr -subj '/CN=localhost/O=lnd'
    openssl req -config $opensslConf -x509 -sha256 -days 1825 -key lnd-key -in lnd.csr -out lnd-cert
    rm lnd.csr
fi

if [[ ! -e loop-key || ! -e loop-cert ]]; then
    openssl ecparam -genkey -name prime256v1 -out loop-key
    openssl req -config $opensslConf -new -sha256 -key loop-key -out loop.csr -subj '/CN=localhost/O=loopd'
    openssl req -config $opensslConf -x509 -sha256 -days 1825 -key loop-key -in loop.csr -out loop-cert
    rm loop.csr
fi
