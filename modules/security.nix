{ config, lib, pkgs, ... }:

with lib;

let
  inherit (config) nix-bitcoin-services;
  dataDir = "/var/lib/dbus-hardening";
  # Mitigates a security issue that allows unprivileged users to read
  # other unprivileged user's processes' credentials from CGroup using
  # `systemctl status`.
  dbus-hardening = pkgs.writeText "dbus.conf" ''
    <?xml version="1.0" encoding="UTF-8"?> <!-- -*- XML -*- -->

    <!DOCTYPE busconfig PUBLIC
     "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">

    <busconfig>
      <policy user="root">
        <allow send_destination="org.freedesktop.systemd1"
          send_interface="org.freedesktop.systemd1.Manager"
          send_member="GetUnitProcesses"/>
      </policy>

      <policy context="mandatory">
        <deny send_destination="org.freedesktop.systemd1"
          send_interface="org.freedesktop.systemd1.Manager"
          send_member="GetUnitProcesses"/>
      </policy>
    </busconfig>
  '';
in {
  config = {
    systemd.tmpfiles.rules = [
      "d '${dataDir}/etc/dbus-1/system.d' 0770 messagebus messagebus - -"
    ];

    services.dbus.packages = [ "${dataDir}" ];

    systemd.services.hardeneddbus = {
      description = "Install hardeneddbus";
      wantedBy = [ "multi-user.target" ];
      script = ''
        cp ${dbus-hardening} ${dataDir}/etc/dbus-1/system.d/dbus.conf
        chmod 640 ${dataDir}/etc/dbus-1/system.d/dbus.conf
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        PrivateNetwork = "true";
        Type = "oneshot";
        User = "messagebus";
        ReadWritePaths = "${dataDir}";
      };
    };
  };
}
