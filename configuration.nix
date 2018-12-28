# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{

  services.nixbitcoin.enable = true;
  # Install and use minimal or all modules
  services.nixbitcoin.modules = "all";

  # FIXME: Define your hostname.
  networking.hostName = "nix-bitcoin";

  imports = [
    ./configuration-nixbitcoin.nix
    # FIXME: Uncomment next line to import your hardware configuration. If so,
    # add the hardware configuration file to the same directory as this file.
    #./hardware-configuration.nix
  ];
  # FIXME: Add your SSH pubkey
  users.users.root = {
    openssh.authorizedKeys.keys = [ "" ];
  };

  # FIXME: Add custom options options (like boot options):

}
