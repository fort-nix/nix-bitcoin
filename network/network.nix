let
  secrets = import ../secrets/secrets.nix;
  bitcoin-rpcpassword = {
    text = secrets.bitcoinrpcpassword;
    destDir = "/secrets/";
    user = "bitcoin";
    group = "bitcoinrpc";
    permissions = "0440";
  };
  lightning-charge-api-token = {
    text = "API_TOKEN=" + secrets.lightning-charge-api-token;
    destDir = "/secrets/";
    user = "clightning";
    group = "clightning";
    permissions = "0440";
  };
  # variable is called CHARGE_TOKEN instead of API_TOKEN
  lightning-charge-api-token-for-nanopos = {
    text = "CHARGE_TOKEN=" + secrets.lightning-charge-api-token;
    destDir = "/secrets/";
    user = "nanopos";
    group = "nanopos";
    permissions = "0440";
  };
  liquid-rpcpassword = {
    text = secrets.liquidrpcpassword;
    destDir = "/secrets/";
    user = "liquid";
    group = "liquid";
    permissions = "0440";
  };
  spark-wallet-login = {
    text = "login=" + "spark-wallet:" + secrets.spark-wallet-password;
    destDir = "/secrets/";
    user = "clightning";
    group = "clightning";
    permissions = "0440";
  };
  nginx_key = {
    keyFile = ../secrets/nginx.key;
    destDir = "/secrets/";
    user = "nginx";
    group = "root";
    permissions = "0440";
  };
  nginx_cert = {
    keyFile = ../secrets/nginx.cert;
    destDir = "/secrets/";
    user = "nginx";
    group = "root";
    permissions = "0440";
  };
in {
  network.description = "Bitcoin Core node";

  bitcoin-node =
    { config, pkgs, ... }:
    let
      bitcoin-node = import ../configuration.nix;
    in {
      deployment.keys = {
        inherit bitcoin-rpcpassword;
      }
      // (if (config.services.lightning-charge.enable) then { inherit lightning-charge-api-token; } else { })
      // (if (config.services.nanopos.enable) then { inherit lightning-charge-api-token-for-nanopos; } else { })
      // (if (config.services.liquidd.enable) then { inherit liquid-rpcpassword; } else { })
      // (if (config.services.spark-wallet.enable) then { inherit spark-wallet-login; } else { })
      // (if (config.services.electrs.enable) then { inherit nginx_key nginx_cert; } else { });
    } // (bitcoin-node { inherit config pkgs; });
}
