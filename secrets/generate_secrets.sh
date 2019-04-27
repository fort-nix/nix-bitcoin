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
    echo "  lightning-charge-api-token = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  liquidrpcpassword = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  spark-wallet-password = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo \}
} >> $SECRETSFILE
echo Done

echo Generate Self-Signed Cert
openssl genrsa -out secrets/ssl_certificate_key.key 2048
openssl req -new -key secrets/ssl_certificate_key.key -out secrets/ssl_certificate.csr -subj "/C=KN"
openssl x509 -req -days 1825 -in secrets/ssl_certificate.csr -signkey secrets/ssl_certificate_key.key -out secrets/ssl_certificate.crt
echo Done
