#!/bin/bash

SECRETSFILE=secrets/secrets.nix

if [ -e "$SECRETSFILE" ]; then
    echo $SECRETSFILE already exists
    exit 1
fi

echo Installing apg through nix-env
nix-env -i apg
echo Write secrets to $SECRETSFILE
{
    echo \{
    echo "  bitcoinrpcpassword = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo "  lightning-charge-api-token = \"$(apg -m 20 -x 20 -M Ncl -n 1)\";"
    echo \}
} >> $SECRETSFILE
echo Done
