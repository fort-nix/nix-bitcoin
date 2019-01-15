# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports = [
    ./nix-bitcoin.nix
    # FIXME: Uncomment next line to import your hardware configuration. If so,
    # add the hardware configuration file to the same directory as this file.
    # This is not needed when deploying to a virtual box.
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
