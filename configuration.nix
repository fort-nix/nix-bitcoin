# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }: { imports = [ ./modules/nix-bitcoin.nix
    # FIXME: Uncomment next line to import your hardware configuration. If so,
    # add the hardware configuration file to the same directory as this file.
    # This is not needed when deploying to a virtual box.
    #./hardware-configuration.nix
  ];
  # FIXME: Enable modules by uncommenting their respective line. Disable
  # modules by commenting out their respective line.  Enable this module to
  # use the nix-bitcoin node configuration. Only disable this if you know what
  # you are doing.
  services.nix-bitcoin.enable = true;
  # Enable this module to use clightning, a Lightning Network implementation
  # in C.
  services.clightning.enable = true;
  # Enable this module to use lightning-charge, a simple drop-in solution for
  # accepting lightning payments. Only enable this if clightning is enabled.
  # services.lightning-charge.enable = true; 
  # Enable this module to use nanopos, a simple Lightning point-of-sale
  # system, powered by Lightning Charge. Only enable this if clightning and
  # lightning-charge are enabled.
  # services.nanopos.enable = true; 
  # Enable this module to use the nix-bitcoin-webindex, a simple website
  # displaying your node information and link to nanopos store. Only enable
  # this if clightning, lightning-charge, and nanopos are enabled.
  # services.nix-bitcoin-webindex.enable = true; 
  # Enable this option to listen for incoming lightning connections. By
  # default nix-bitcoin nodes offer outgoing connectivity.  
  # services.clightning.autolisten = true; 
  # Enable this module to use liquidd, a daemon for an inter-exchange
  # settlement network linking together cryptocurrency exchanges and
  # institutions around the world.  
  # services.liquidd.enable = true; 
  # Enable this module to use spark-wallet, a minimalistic wallet GUI for
  # c-lightning, accessible over the web or through mobile and desktop apps.
  # Only enable this if clightning is enabled.  
  # services.spark-wallet.enable = true; 
  # Enable this module to use electrs, an efficient re-implementation of
  # Electrum Server in Rust.
  # services.electrs.enable = true;

  # FIXME: Define your hostname.
  networking.hostName = "nix-bitcoin";
  time.timeZone = "UTC";

  # FIXME: Add your SSH pubkey
  services.openssh.enable = true;
  users.users.root = {
    openssh.authorizedKeys.keys = [ "" ];
  };

  # FIXME: add packages you need in your system
  environment.systemPackages = with pkgs; [
    vim
  ];

  # FIXME: Turn on the binary cache by commenting out the next line. When the
  # binary cache is enabled you are retrieving builds from a trusted third
  # party which can compromise your system. As a result, the cache should only
  # be enabled to speed up deployment of test systems.
  nix.binaryCaches = [];

  # FIXME: Add custom options (like boot options, output of
  # nixos-generate-config, etc.):


  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
