# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports = [
    ./nix-bitcoin.nix
    # FIXME: Uncomment next line to import your hardware configuration. If so,
    # add the hardware configuration file to the same directory as this file.
    #./hardware-configuration.nix
  ];
  services.nix-bitcoin.enable = true;
  # FIXME Install and use minimal or all modules
  services.nix-bitcoin.modules = "all";

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

  # FIXME: Turn off the binary cache by setting binaryCaches to empty list.
  # This means that it will take a while for all packages to be built but it
  # prevents a compromised cache taking over your system. As a result, the next
  # line should be uncommented in production systems.
  # nix.binaryCaches = [];

  # FIXME: Add custom options options (like boot options):


  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
