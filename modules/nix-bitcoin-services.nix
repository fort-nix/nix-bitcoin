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
      LockPersonality = "true";
  };
in
{
  inherit defaultHardening;
  # node applications apparently rely on memory write execute
  nodeHardening = defaultHardening // { MemoryDenyWriteExecute = "false"; };
}



