# Define an operator user for convenient interactive access to nix-bitcoin
# features and services.
#
# When using nix-bitcoin as part of a larger system config, set
# `nix-bitcoin.operator.name` to your main user name.

{ config, lib, pkgs, ... }:

with lib;
let
  options.nix-bitcoin.operator = {
    enable = mkEnableOption "operator user";
    name = mkOption {
      type = types.str;
      default = "operator";
      description = "User name.";
    };
    groups = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Extra groups.";
    };
    allowRunAsUsers = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Users as which the operator is allowed to run commands.";
    };
  };

  cfg = config.nix-bitcoin.operator;
in {
  inherit options;

  config = mkIf cfg.enable {
    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = [
        "systemd-journal"
        "proc" # Enable full /proc access and systemd-status
      ] ++ cfg.groups;
    };

    security = mkIf (cfg.allowRunAsUsers != []) {
      # Use doas instead of sudo if enabled
      doas.extraConfig = mkIf config.security.doas.enable ''
        ${lib.concatMapStrings (user: "permit nopass ${cfg.name} as ${user}\n") cfg.allowRunAsUsers}
      '';
      sudo.extraConfig = mkIf (!config.security.doas.enable) ''
        ${cfg.name} ALL=(${builtins.concatStringsSep "," cfg.allowRunAsUsers}) NOPASSWD: ALL
      '';
    };
  };
}
