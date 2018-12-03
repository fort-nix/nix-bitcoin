# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  # Custom packages
  nodeinfo = (import pkgs/nodeinfo.nix);
  lightning-charge = import pkgs/lightning-charge.nix { inherit pkgs; };
  nanopos = import pkgs/nanopos.nix { inherit pkgs; };
  liquidd = import pkgs/liquidd.nix;
in {
  disabledModules = [ "services/security/tor.nix" ];

  imports =
    [
      ./modules/nixbitcoin.nix
    ];

  # Turn off binary cache by setting binaryCaches to empty list
  # nix.binaryCaches = [];

  networking.hostName = "nix-bitcoin"; # Define your hostname.
  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [
    vim tmux
  ];

  nixpkgs.config.packageOverrides = pkgs: {
    inherit nodeinfo;
    inherit lightning-charge;
    inherit nanopos;
    liquidd = (pkgs.callPackage liquidd { });
  };

  services.openssh.enable = true;
  networking.firewall.enable = true;
  services.nixbitcoin.enable = true;
  # Install and use minimal or all modules
  services.nixbitcoin.modules = "all";

   # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?

}
