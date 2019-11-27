{ secretsFile ? null, config ? null }:
let
  secrets = import secretsFile;
  secretsDir = "/secrets/";
  secret = { text ? null, keyFile ? null, user, group ? user }: {
    inherit text keyFile user group;
    destDir = secretsDir;
    permissions = "0440";
  };
in rec {
  allSecrets = {
    bitcoin-rpcpassword = secret {
      text = secrets.bitcoinrpcpassword;
      user = "bitcoin";
      group = "bitcoinrpc";
    };
    lnd-wallet-password = secret {
      text = secrets.lnd-wallet-password;
      user = "lnd";
    };
    lightning-charge-api-token = secret {
      text = "API_TOKEN=" + secrets.lightning-charge-api-token;
      user = "clightning";
    };
    # variable is called CHARGE_TOKEN instead of API_TOKEN
    lightning-charge-api-token-for-nanopos = secret {
      text = "CHARGE_TOKEN=" + secrets.lightning-charge-api-token;
      user = "nanopos";
    };
    liquid-rpcpassword = secret {
      text = secrets.liquidrpcpassword;
      user = "liquid";
    };
    spark-wallet-login = secret {
      text = "login=" + "spark-wallet:" + secrets.spark-wallet-password;
      user = "clightning";
    };
    nginx_key = secret {
      keyFile = toString ../../secrets/nginx.key;
      user = "nginx";
      group = "root";
    };
    nginx_cert = secret {
      keyFile = toString ../../secrets/nginx.cert;
      user = "nginx";
      group = "root";
    };
    lnd_key = secret {
      keyFile = toString ../../secrets/lnd.key;
      user = "lnd";
    };
    lnd_cert = secret {
      keyFile = toString ../../secrets/lnd.cert;
      user = "lnd";
    };
  };

  activeSecrets = let
    secretsFor = service: attrs: if service.enable then attrs else {};
  in with allSecrets;
       (secretsFor config.services.bitcoind { inherit bitcoin-rpcpassword; })
    // (secretsFor config.services.lnd { inherit lnd-wallet-password lnd_key lnd_cert; })
    // (secretsFor config.services.lightning-charge { inherit lightning-charge-api-token; })
    // (secretsFor config.services.nanopos { inherit lightning-charge-api-token-for-nanopos; })
    // (secretsFor config.services.liquidd { inherit liquid-rpcpassword; })
    // (secretsFor config.services.spark-wallet { inherit spark-wallet-login; })
    // (secretsFor config.services.electrs { inherit nginx_key nginx_cert; });
}
