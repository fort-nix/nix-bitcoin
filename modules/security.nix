{ config, lib, pkgs, ... }:

with lib;
{
  options = {
    nix-bitcoin.security.dbusHideProcessInformation = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Only allow users with group `proc` to retrieve systemd unit information like
        cgroup paths (i.e. (sub)process command lines) via D-Bus.

        This mitigates a systemd security issue where (sub)process command lines can
        be retrieved by services even when their access to /proc is restricted
        (via ProtectProc).

        This option works by restricting the D-Bus method `GetUnitProcesses`, which
        is also used internally by {command}`systemctl status`.
      '';
    };
  };

  config = mkIf config.nix-bitcoin.security.dbusHideProcessInformation {
    users.groups.proc = {};
    nix-bitcoin.operator.groups = [ "proc" ]; # Enable operator access to systemd-status

    services.dbus.packages = lib.mkAfter [ # Apply at the end to override the default policy
      (pkgs.writeTextDir "etc/dbus-1/system.d/dbus.conf" ''
        <busconfig>
          <policy context="default">
            <deny
              send_destination="org.freedesktop.systemd1"
              send_interface="org.freedesktop.systemd1.Manager"
              send_member="GetUnitProcesses"
            />
          </policy>
          <policy group="proc">
            <allow
              send_destination="org.freedesktop.systemd1"
              send_interface="org.freedesktop.systemd1.Manager"
              send_member="GetUnitProcesses"
            />
          </policy>
        </busconfig>
      '')
    ];
  };
}
