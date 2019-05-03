{ config, lib, pkgs, ... }:

with lib;

let
  defaultHardening = {
      PrivateTmp = "true";
      ProtectSystem = "full";
      ProtectHome = "true";
      NoNewPrivileges = "true";
      PrivateDevices = "true";
      MemoryDenyWriteExecute = "true";
      ProtectKernelTunables = "true";
      ProtectKernelModules = "true";
      ProtectControlGroups = "true";
      RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
      RestrictNamespaces = "true";
      LockPersonality = "true";
      IPAddressDeny = "any";
  };
in
{
  inherit defaultHardening;
  # nodejs applications apparently rely on memory write execute
  nodejs = { MemoryDenyWriteExecute = "false"; };
  # Allow tor traffic. Allow takes precedence over Deny.
  allowTor = {
    IPAddressAllow = "127.0.0.1/32 ::1/128";
  };
  # Allow any traffic
  allowAnyIP = { IPAddressAllow = "any"; };

   enforceTor = mkOption {
     type = types.bool;
     default = false;
     description = ''
       "Whether to force Tor on a service by only allowing connections from and
       to 127.0.0.1;";
     '';
   };
}



