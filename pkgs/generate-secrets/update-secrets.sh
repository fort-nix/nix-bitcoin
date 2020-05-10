#!/usr/bin/env bash

set -eo pipefail

# Update secrets from the old format to the current one where each secret
# has a local source file.

reportError() {
    echo "Updating secrets failed. (Error in line $1)"
    echo "The secret files have been moved to secrets/old-secrets"
}
trap 'reportError $LINENO' ERR

echo "Updating old secrets to the current format."

mkdir old-secrets
# move all files into old-secrets
shopt -s extglob dotglob
mv !(old-secrets) old-secrets
shopt -u dotglob

secrets=$(cat old-secrets/secrets.nix)

extractPassword() {
    pwName="$1"
    destFile="${2:-$pwName}"
    echo "$secrets" | sed -nE "s/.*?$pwName = \"(.*?)\".*/\1/p" > "$destFile"
}

rename() {
    old="old-secrets/$1"
    if [[ -e $old ]]; then
        cp "$old" "$2"
    fi
}

extractPassword bitcoinrpcpassword bitcoin-rpcpassword
extractPassword lnd-wallet-password
extractPassword liquidrpcpassword liquid-rpcpassword
extractPassword lightning-charge-api-token lightning-charge-token
extractPassword spark-wallet-password

rename lnd.key lnd-key
rename lnd.cert lnd-cert

rm -r old-secrets
