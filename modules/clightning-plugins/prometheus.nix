{ config, lib, ... }:

with lib;
let cfg = config.services.clightning.plugins.prometheus; in
{
  options.services.clightning.plugins.prometheus = {
    enable = mkEnableOption "Prometheus (clightning plugin)";
    listen = mkOption {
      type = types.str;
      default = "0.0.0.0:9750";
      description = "Address and port to bind to.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.prometheus.path}
      prometheus-listen=${cfg.listen}
    '';
  };
}
