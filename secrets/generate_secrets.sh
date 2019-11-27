#!/bin/sh

opensslConf=${1:-openssl.cnf}
secretsFile=secrets.nix

if [ ! -e "$secretsFile" ]; then
    echo Write secrets to $secretsFile
    makepw="apg -m 20 -x 20 -M Ncl -n 1"
    {
        echo \{
        echo "  bitcoinrpcpassword = \"$($makepw)\";"
        echo "  lnd-wallet-password = \"$($makepw)\";"
        echo "  lightning-charge-api-token = \"$($makepw)\";"
        echo "  liquidrpcpassword = \"$($makepw)\";"
        echo "  spark-wallet-password = \"$($makepw)\";"
        echo \}
    } >> $secretsFile
    echo Done
else
    echo $secretsFile already exists. Skipping.
fi

if [ ! -e nginx.key ] || [ ! -e nginx.cert ]; then
    echo Generate Nginx Self-Signed Cert
    openssl genrsa -out nginx.key 2048
    openssl req -new -key nginx.key -out nginx.csr -subj "/C=KN"
    openssl x509 -req -days 1825 -in nginx.csr -signkey nginx.key -out nginx.cert
    rm nginx.csr
    echo Done
else
    echo Nginx Cert already exists. Skipping.
fi

if [ ! -e lnd.key ] || [ ! -e lnd.cert ]; then
    echo Generate LND compatible TLS Cert
    openssl ecparam -genkey -name prime256v1 -out lnd.key
    openssl req -config $opensslConf -new -sha256 -key lnd.key -out lnd.csr -subj '/CN=localhost/O=lnd'
    openssl req -config $opensslConf -x509 -sha256 -days 1825 -key lnd.key -in lnd.csr -out lnd.cert
    rm lnd.csr
    echo Done
else
    echo LND cert already exists. Skipping.
fi
