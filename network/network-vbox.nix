{
  bitcoin-node =
    { config, pkgs, ... }:
    {
      deployment.targetEnv = "virtualbox";
      deployment.virtualbox.memorySize = 4096; # megabytes
      deployment.virtualbox.vcpu = 4; # number of cpus
      deployment.virtualbox.headless = true;
      # Set up 250 GB disk, which should be enough for bitcoind and clightning
      # for now.
      deployment.virtualbox.disks.disk1.size = 1024*250;
    };
}
