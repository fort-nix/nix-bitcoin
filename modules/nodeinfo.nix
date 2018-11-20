{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    systemd.services.nodeinfo = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c ${pkgs.nodeinfo}/bin/nodeinfo";
        user = "root";
        type = "oneshot";
      };
    };
  };
}
