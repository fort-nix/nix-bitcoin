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
  ssl_certificate_key = {
    keyFile = ../secrets/ssl_certificate_key.key;
    destDir = "/secrets/";
    user = "nginx";
    group = "nginx";
    permissions = "0440";
  };
  ssl_certificate = {
    keyFile = ../secrets/ssl_certificate.crt;
    destDir = "/secrets/";
    user = "nginx";
    group = "nginx";
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
      // (if (config.services.electrs.enable) then { inherit ssl_certificate_key ssl_certificate; } else { });
    } // (bitcoin-node { inherit config pkgs; });
}
