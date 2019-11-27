let
  secrets = import ../secrets/secrets.nix;
  bitcoin-rpcpassword = {
    text = secrets.bitcoinrpcpassword;
    destDir = "/secrets/";
    user = "bitcoin";
    group = "bitcoinrpc";
    permissions = "0440";
  };
  lnd-wallet-password = {
    text = secrets.lnd-wallet-password;
    destDir = "/secrets/";
    user = "lnd";
    group = "lnd";
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
    keyFile = toString ../../secrets/nginx.key;
    destDir = "/secrets/";
    user = "nginx";
    group = "root";
    permissions = "0440";
  };
  nginx_cert = {
    keyFile = toString ../../secrets/nginx.cert;
    destDir = "/secrets/";
    user = "nginx";
    group = "root";
    permissions = "0440";
  };
  lnd_key = {
    keyFile = toString ../../secrets/lnd.key;
    destDir = "/secrets/";
    user = "lnd";
    group = "lnd";
    permissions = "0440";
  };
  lnd_cert = {
    keyFile = toString ../../secrets/lnd.cert;
    destDir = "/secrets/";
    user = "lnd";
    group = "lnd";
    permissions = "0440";
  };
in {
  network.description = "Bitcoin Core node";

  bitcoin-node =
    { config, pkgs, lib, ... }: {
      imports = [ ../configuration.nix ];

      deployment.keys = {
        inherit bitcoin-rpcpassword;
      }
      // (if (config.services.lnd.enable) then { inherit lnd-wallet-password lnd_key lnd_cert; } else { })
      // (if (config.services.lightning-charge.enable) then { inherit lightning-charge-api-token; } else { })
      // (if (config.services.nanopos.enable) then { inherit lightning-charge-api-token-for-nanopos; } else { })
      // (if (config.services.liquidd.enable) then { inherit liquid-rpcpassword; } else { })
      // (if (config.services.spark-wallet.enable) then { inherit spark-wallet-login; } else { })
      // (if (config.services.electrs.enable) then { inherit nginx_key nginx_cert; } else { });

      # nixops makes the secrets directory accessible only for users with group 'key'.
      # For compatibility with other deployment methods besides nixops, we forego the
      # use of the 'key' group and make the secrets dir world-readable instead.
      # This is safe because all containing files have their specific private
      # permissions set.
      systemd.services.allowSecretsDirAccess = {
        requires = [ "keys.target" ];
        after = [ "keys.target" ];
        script = "chmod o+x /secrets";
        serviceConfig.Type = "oneshot";
      };

      systemd.targets.nix-bitcoin-secrets = {
        requires = [ "allowSecretsDirAccess.service" ];
        after = [ "allowSecretsDirAccess.service" ];
      };
    };
}
