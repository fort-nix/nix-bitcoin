# Define an operator user for convenient interactive access to nix-bitcoin
# features and services.
#
# When using nix-bitcoin as part of a larger system config, set
# `nix-bitcoin.operator.name` to your main user name.

{ config, lib, pkgs, options, ... }:

with lib;
let
  cfg = config.nix-bitcoin.operator;
in {
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
    sudoUsers = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Users as which the operator is allowed to run commands.";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = [
        "systemd-journal"
        "proc" # Enable full /proc access and systemd-status
      ] ++ cfg.groups;
    };

    security.sudo.extraConfig = mkIf (cfg.sudoUsers != []) (let
      users = builtins.concatStringsSep "," cfg.sudoUsers;
    in ''
      ${cfg.name} ALL=(${users}) NOPASSWD: ALL
    '');
  };
}
