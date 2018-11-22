# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  # custom package
  nodeinfo = (import pkgs/nodeinfo.nix);
in {
  disabledModules = [ "services/security/tor.nix" ];

  imports =
    [
      ./modules/nixbitcoin.nix
    ];

  # TODO: does that destroy the channels symlink?
  # turn off binary cache by passing the empty list
  #nix.binaryCaches = [];

  networking.hostName = "nix-bitcoin"; # Define your hostname.
  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [
     vim tmux clightning bitcoin
     nodeinfo
  ];
  nixpkgs.config.packageOverrides = pkgs: {
    inherit nodeinfo;
  };

  services.openssh.enable = true;

#  users.users.root = {
#     openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILacgZRwLsiICNHGHY2TG2APeuxFsrw6Cg13ZTMQpNqA nickler@rick" ];
#  };


  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = true;

  services.bitcoin.enable = true;
  # make an onion listen node
  services.tor.enable = true;
  services.tor.client.enable = true;
  #services.bitcoin.proxy = services.tor.client.socksListenAddress;
  services.nixbitcoin.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };


  # List packages installed in system profile. To search, run:
  # $ nix search wget

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:


  # Open ports in the firewall.
  # Or disable the firewall altogether.

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.guest = {
  #   isNormalUser = true;
  #   uid = 1000;
  # };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?

}
