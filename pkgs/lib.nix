lib: pkgs:

with lib;

# See `man systemd.exec` and `man systemd.resource-control` for an explanation
# of the systemd-related options available through this module.
let self = {
  # These settings roughly follow systemd's "strict" security profile
  defaultHardening = {
      PrivateTmp = "true";
      ProtectSystem = "strict";
      ProtectHome = "true";
      NoNewPrivileges = "true";
      PrivateDevices = "true";
      MemoryDenyWriteExecute = "true";
      ProtectKernelTunables = "true";
      ProtectKernelModules = "true";
      ProtectKernelLogs = "true";
      ProtectClock = "true";
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectControlGroups = "true";
      RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
      RestrictNamespaces = "true";
      LockPersonality = "true";
      IPAddressDeny = "any";
      PrivateUsers = "true";
      RestrictSUIDSGID = "true";
      RemoveIPC = "true";
      RestrictRealtime = "true";
      ProtectHostname = "true";
      CapabilityBoundingSet = "";
      # @system-service whitelist and docker seccomp blacklist (except for "clone"
      # which is a core requirement for systemd services)
      # @system-service is defined in src/shared/seccomp-util.c (systemd source)
      SystemCallFilter = [ "@system-service" "~add_key clone3 get_mempolicy kcmp keyctl mbind move_pages name_to_handle_at personality process_vm_readv process_vm_writev request_key set_mempolicy setns unshare userfaultfd" ];
      SystemCallArchitectures = "native";
  };

  allowNetlink = {
    RestrictAddressFamilies = self.defaultHardening.RestrictAddressFamilies + " AF_NETLINK";
  };

  # nodejs applications apparently rely on memory write execute
  nodejs = { MemoryDenyWriteExecute = "false"; };

  # Allow takes precedence over Deny.
  allowLocalIPAddresses = {
    IPAddressAllow = "127.0.0.1/32 ::1/128 169.254.0.0/16";
  };
  allowAllIPAddresses = { IPAddressAllow = "any"; };
  allowTor = self.allowLocalIPAddresses;
  allowedIPAddresses = onlyLocal:
    if onlyLocal
    then self.allowLocalIPAddresses
    else self.allowAllIPAddresses;

  enforceTor = mkOption {
    type = types.bool;
    default = false;
    description = ''
      Whether to force Tor on a service by only allowing connections from and
      to 127.0.0.1;
    '';
  };

  script = name: src: pkgs.writers.writeBash name ''
    set -eo pipefail
    ${src}
  '';

  # Used for ExecStart*
  rootScript = name: src: "+${self.script name src}";

  cliExec = mkOption {
    # Used by netns-isolation to execute the cli in the service's private netns
    internal = true;
    type = types.str;
    default = "exec";
  };

  mkOnionService = map: {
    map = [ map ];
    version = 3;
  };
}; in self
