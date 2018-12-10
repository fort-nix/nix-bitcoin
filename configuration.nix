# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{

  services.nixbitcoin.enable = true;
  # Install and use minimal or all modules
  services.nixbitcoin.modules = "all";

  networking.hostName = "nix-bitcoin"; # Define your hostname.

  imports = [
    ./configuration-nix-bitcoin.nix
    #./hardware-configuration.nix
  ];
  # Add custom options options (like boot options) here:
}
