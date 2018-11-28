let
  secrets = import ./secrets/secrets.nix;
in
{
  bitcoin-node =
    { config, pkgs, ... }:
    { deployment.targetEnv = "virtualbox";
      deployment.virtualbox.memorySize = 2048; # megabytes
      deployment.virtualbox.vcpu = 2; # number of cpus
      deployment.virtualbox.headless = true;

      deployment.keys.bitcoin-rpcpassword.text = secrets.bitcoinrpcpassword;
      deployment.keys.bitcoin-rpcpassword.destDir = "/secrets/";
      deployment.keys.bitcoin-rpcpassword.user = "bitcoin";
      deployment.keys.bitcoin-rpcpassword.group = "bitcoinrpc";
      deployment.keys.bitcoin-rpcpassword.permissions = "0440";
    };
}
