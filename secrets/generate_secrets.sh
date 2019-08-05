#!/bin/sh

SECRETSFILE=secrets/secrets.nix

if [ -e "$SECRETSFILE" ]; then
    echo $SECRETSFILE already exists. No new secrets were generated.
    exit 1
fi

echo Write secrets to $SECRETSFILE
{
    echo \{
    echo "  bitcoinrpcpassword = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  lnd-wallet-password = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  lightning-charge-api-token = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  liquidrpcpassword = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  spark-wallet-password = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo \}
} >> $SECRETSFILE
echo Done

echo Generate Self-Signed Cert
openssl genrsa -out secrets/nginx.key 2048
openssl req -new -key secrets/nginx.key -out secrets/nginx.csr -subj "/C=KN"
openssl x509 -req -days 1825 -in secrets/nginx.csr -signkey secrets/nginx.key -out secrets/nginx.cert
rm secrets/nginx.csr
echo Done

echo Generate LND compatible TLS Cert
openssl ecparam -genkey -name prime256v1 -out secrets/lnd.key
openssl req -config secrets/openssl.cnf -new -sha256 -key secrets/lnd.key -out secrets/lnd.csr -subj '/CN=localhost/O=lnd'
openssl req -config secrets/openssl.cnf -x509 -sha256 -days 1825 -key secrets/lnd.key -in secrets/lnd.csr -out secrets/lnd.cert
rm secrets/lnd.csr
echo Done
