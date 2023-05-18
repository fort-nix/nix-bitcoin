# MYBONK console default configuration file. 
# For testing only (it runs on SIGNET).

{ config, pkgs, lib, ... }:

{
  imports =
    [
      <nix-bitcoin/modules/presets/secure-node.nix>
      <nix-bitcoin/modules/presets/hardened.nix>
      
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "mybonk_console"; # FIXME: Define a hostname of your choice.
  networking.wireless.enable = false; # We prefer our nodes not to operate over WiFi. 

  networking.firewall.checkReversePath = "loose"; # Use this setting because strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups
#  networking.networkmanager.enable = true;
  
  # Set your time zone.
  time.timeZone = "Europe/Brussels"; # FIXME: Adjust for your timezone.

  # FIXME: Configure keymap in X11
  services.xserver = {
    layout = "fr";
    xkbVariant = "mac";
  };

  # FIXME: Configure console keymap
  console.keyMap = "fr";

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  wget
  git
  vim
  glances
  websocketd
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
    passwordAuthentication = false;
    #permitRootLogin = "yes";
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDNI9e9FtUAuBLAs3Xjcgm78yD6psH+iko+DXOqeEO0VQY+faUKJ0KYF8hp2x8WYtlB7BsrYHVfupwk5YwDSvN36d0KgvYj8hqGRbeKAPynmh5NC1IpX3YU911dNOieDAlGaqFnCicl30FER/bXPfOUCHFm0X7YGudqTU5Zm2TkPKvdH7y+a5mYpZbT2cDKEcRcGbWvUcagw0d0e0jLnXwlTO93WVLpyf5hCmbKFGVpIK1ssx1ij0ZB5rmqlVSscbHY5irt8slXoTOW9go/EpkPD5AWb7RhtTbkA4Vrwk0zqbwoRIIjHF75Z0zK/5oTBVVxEtru96nhXzMII/1D2MTqfD43SK34s7RSklTQjMPlewseDAZtL75MRf1t0eurl1jX9c1gKh9FiGqxTxzIGnfCFIhAISOYD+2m0r9xUaBETOUS1JK3pZc0kqrAStBdah5XjqyZwGbKFzaotLuLRab/GdEGA4bjBQ8nnh+0m5AZIHxPvqh3EyRd4eoT8IpQPOE= debian@debian11"
    ]
;
  };

  ### BITCOIND
  # Bitcoind is enabled by default via secure-node.nix.
  services.bitcoind.dataDir = "/data/bitcoind"; 
  #
  # Set this option to enable pruning with a specified MiB value.
  # clightning is compatible with pruning. See
  # https://github.com/ElementsProject/lightning/#pruning for more information.
  # LND and electrs are not compatible with pruning.
  # services.bitcoind.prune = 1000;
  #
  # Set this to accounce the onion service address to peers.
  # The onion service allows accepting incoming connections via Tor.
  nix-bitcoin.onionServices.bitcoind.public = true;
  #
  # You can add options that are not defined in modules/bitcoind.nix as follows
  
  services.bitcoind.signet = true;  

  services.bitcoind.extraConfig = ''
#    maxorphantx=110
  '';

  ### CLIGHTNING
  # Enable clightning, a Lightning Network implementation in C.
  services.clightning.enable = true;
  #
  # Set this to create an onion service by which clightning can accept incoming connections
  # via Tor.
  # The onion service is automatically announced to peers.
  nix-bitcoin.onionServices.clightning.public = true;
  #
  # == Plugins
  # See ../README.md (Features ?~F~R clightning) for the list of available plugins.
  services.clightning.plugins.prometheus.enable = true;
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
      onion = true;
    };
  };

  users.users.operator.extraGroups = [ "wheel" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  # The nix-bitcoin release version that your config is compatible with.
  # When upgrading to a backwards-incompatible release, nix-bitcoin will display an
  # an error and provide instructions for migrating your config to the new release.
  nix-bitcoin.configVersion = "0.0.85";

}

