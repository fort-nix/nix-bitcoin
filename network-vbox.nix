let
  secrets = import ./secrets/secrets.nix;
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
in
{
  bitcoin-node =
    { config, pkgs, ... }:
    {
      deployment.targetEnv = "virtualbox";
      deployment.virtualbox.memorySize = 2048; # megabytes
      deployment.virtualbox.vcpu = 2; # number of cpus
      deployment.virtualbox.headless = true;

      deployment.keys = {
        inherit bitcoin-rpcpassword lightning-charge-api-token;
      }
      // (if (config.services.nanopos.enable) then { inherit lightning-charge-api-token-for-nanopos; } else { })
      // (if (config.services.liquidd.enable) then { inherit liquid-rpcpassword; } else { });
    };
}
