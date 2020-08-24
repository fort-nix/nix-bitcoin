{ config, lib, pkgs, options, ... }:

{
  options = {
    nix-bitcoin.security.hideProcessInformation = options.security.hideProcessInformation;
  };

  config = lib.mkIf config.nix-bitcoin.security.hideProcessInformation {
    # Only show the current user's processes in /proc.
    # Users with group 'proc' can still access all processes.
    security.hideProcessInformation = true;

    # This mitigates a systemd security issue leaking (sub)process
    # command lines.
    # Only allow users with group 'proc' to retrieve systemd unit information like
    # cgroup paths (i.e. (sub)process command lines) via D-Bus.
    # This D-Bus call is used by `systemctl status`.
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
