# MYBONK console default configuration file. 
# For testing only.

{ config, pkgs, lib, ... }:

{
  imports =
    [
      <nix-bitcoin/modules/presets/secure-node.nix>
      <nix-bitcoin/modules/presets/hardened.nix>
    
      # Following is temprary until mempool is re-integrated in nix-bitcoin. 
      (import (builtins.fetchTarball {
        url = "https://github.com/fort-nix/nix-bitcoin-mempool/archive/402a8a6de1eb6d20d2b36e13d3461e1b85f0bbef.tar.gz";
        sha256 = "0zj2g0i0mj9x9svggbja6ja6yb47gdzx8rw4cw26ka169a0mj6sb";
      })).nixosModules.default
 
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "mybonk-jay"; # FIXME: Define a hostname of your choice.
  networking.wireless.enable = false; # We prefer our nodes not to operate over WiFi. 

  # Use this setting 'loose' because strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups
  networking.firewall.checkReversePath = "loose";
  networking.networkmanager.enable = true;
  
  # Set your time zone.
  time.timeZone = "Europe/Brussels"; # FIXME: Adjust for your timezone.

  # FIXME: Configure keymap in X11
  services.xserver = {
    layout = "fr";
    xkbVariant = "mac";
  };

  # FIXME: Configure console keymap
  console.keyMap = "fr";

  # Define a user account. Don't forget to set a password with 'passwd'
  users.users.mybonk = {
    isNormalUser = true;
    description = "mybonk";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  wget
  git
  vim
  ripgrep
  pv
  htop
  glances
  websocketd
  geekbench 
  ];


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable tailscale
  services.tailscale.enable = true;
  # Tell the firewall to implicitly trust packets routed over Tailscale:
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.openssh = {
    enable = true;
    passwordAuthentication = true;
    permitRootLogin = "yes";
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      # FIXME: Replace this with your SSH pubkey
      "ssh-ed25519 AAAAC3..."
    ];
  };
  ### BITCOIND
  # Bitcoind is enabled by default via secure-node.nix.

  services.bitcoind = {
    dataDir = "/data/bitcoind";
    signet = true;
    tor.enforce = false;
    tor.proxy = false;
    extraConfig = ''
      mempoolfullrbf=1
    '';
  };
  nix-bitcoin.onionServices.bitcoind.public = true;


  ### CLIGHTNING
  services.clightning = {
    dataDir = "/data/clightning"; 
    enable = true;
    tor.enforce = false;
    tor.proxy = false;
    extraConfig = ''
      #FIXME below choose an alias name of your node
      alias=FIXME
    '';
    
  }; 
  nix-bitcoin.onionServices.clightning.public = true;
  systemd.services.clightning.serviceConfig.TimeoutStartSec = "5m";
  #
  # == Plugins
  # See ../README.md (Features ?~F~R clightning) for the list of available plugins.
  #services.clightning.plugins.prometheus.enable = true;
  #
  # == REST server
  # Set this to create a clightning REST onion service.
  # This also adds binary `lndconnect-clightning` to the system environment.
  # This binary creates QR codes or URLs for connecting applications to clightning
  # via the REST onion service.
  # You can also connect via WireGuard instead of Tor.
  # See ../docs/services.md for details.
  #
  services.clightning-rest = {
    enable = true;
    lndconnect = {
      enable = true;
    };
  };

  services.rtl = {
    enable = true;
    nodes.clightning.enable = true;
  };


  #services.electrs.enable = true;

  ### FULCRUM
  # Set this to enable fulcrum, an Electrum server implemented in C++.
  #
  # Compared to electrs, fulcrum has higher storage demands but
  # can serve arbitrary address queries instantly.
  #
  # Before enabling fulcrum, and for more info on storage demands,
  # see the description of option `enable` in ../modules/fulcrum.nix
  #
  services.fulcrum = {
    dataDir = "/data/fulcrum";
    enable = false;
    port = 50011;
  };


  services.mempool = {
    enable = false;
    electrumServer = "fulcrum";
    #tor = {
    #  proxy = true;
      #enforce = true;
    #};
  };
  #nix-bitcoin.onionServices.mempool-frontend.enable = false;


  users.users.operator.extraGroups = [ "wheel" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It is perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  # The nix-bitcoin release version that your config is compatible with.
  # When upgrading to a backwards-incompatible release, nix-bitcoin will display an
  # an error and provide instructions for migrating your config to the new release.
  nix-bitcoin.configVersion = "0.0.85";

}

