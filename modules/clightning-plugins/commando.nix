{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.commando; in
{
  options.services.clightning.plugins.commando = {
    enable = mkEnableOption "commando (clightning plugin)";
    readers = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "0266e4598d1d3c415f572a8488830b60f7e744ed9235eb0b1ba93283b315c03518" ];
      description = ''
        IDs of nodes which can execute read-only commands (list*, get*, ...).
      '';
    };
    writers = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "0266e4598d1d3c415f572a8488830b60f7e744ed9235eb0b1ba93283b315c03518" ];
      description = ''
        IDs of nodes which can execute any commands.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.commando.path}
    ''
    + concatMapStrings (reader: ''
      commando_reader=${reader}
    '') cfg.readers
    + concatMapStrings (writer: ''
      commando_writer=${writer}
    '') cfg.writers;
  };
}
