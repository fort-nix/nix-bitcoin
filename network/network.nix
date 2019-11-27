let
  secrets = import ../secrets/secrets.nix;

  secretsDir = "/secrets/";
  secret = { text ? null, keyFile ? null, user, group ? user }: {
    inherit text user group;
    destDir = secretsDir;
    permissions = "0440";
  };

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
