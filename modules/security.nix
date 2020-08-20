{ config, lib, pkgs, ... }:

{
  # Only show the current user's processes in /proc.
  # Users with group 'proc' can still access all processes.
  security.hideProcessInformation = true;

  # This mitigates a systemd security issue leaking (sub)process
  # command lines.
  # Only allow root to retrieve systemd unit information like
  # cgroup paths (i.e. (sub)process command lines) via D-Bus.
  # This D-Bus call is used by `systemctl status`.
  services.dbus.packages = [ (pkgs.writeTextDir "etc/dbus-1/system.d/dbus.conf" ''
    <?xml version="1.0" encoding="UTF-8"?> <!-- -*- XML -*- -->

    <!DOCTYPE busconfig PUBLIC
     "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">

      <policy context="mandatory">
        <deny send_destination="org.freedesktop.systemd1"
          send_interface="org.freedesktop.systemd1.Manager"
          send_member="GetUnitProcesses"/>
      </policy>
    </busconfig>
  '') ];
}
