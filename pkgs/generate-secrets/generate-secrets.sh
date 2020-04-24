#!/usr/bin/env bash

opensslConf=${1:-openssl.cnf}

makePasswordSecret() {
    [[ -e $1 ]] || apg -m 20 -x 20 -M Ncl -n 1 > "$1"
}

makePasswordSecret bitcoin-rpcpassword
makePasswordSecret lnd-wallet-password
makePasswordSecret liquid-rpcpassword
makePasswordSecret lightning-charge-token
makePasswordSecret spark-wallet-password

[[ -e lightning-charge-env ]] || echo "API_TOKEN=$(cat lightning-charge-token)" > lightning-charge-env
[[ -e nanopos-env          ]] || echo "CHARGE_TOKEN=$(cat lightning-charge-token)" > nanopos-env
[[ -e spark-wallet-login   ]] || echo "login=spark-wallet:$(cat spark-wallet-password)" > spark-wallet-login

if [[ ! -e nginx-key || ! -e nginx-cert ]]; then
    openssl genrsa -out nginx-key 2048
    openssl req -new -key nginx-key -out nginx.csr -subj '/CN=localhost/O=electrs'
    openssl x509 -req -days 1825 -in nginx.csr -signkey nginx-key -out nginx-cert
    rm nginx.csr
fi

if [[ ! -e lnd-key || ! -e lnd-cert ]]; then
    openssl ecparam -genkey -name prime256v1 -out lnd-key
    openssl req -config $opensslConf -new -sha256 -key lnd-key -out lnd.csr -subj '/CN=localhost/O=lnd'
    openssl req -config $opensslConf -x509 -sha256 -days 1825 -key lnd-key -in lnd.csr -out lnd-cert
    rm lnd.csr
fi
