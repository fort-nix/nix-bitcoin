{ config, lib, pkgs, ... }:

with lib;
let
  options.nix-bitcoin.operator = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to define a user named `operator` for convenient interactive access
        to nix-bitcoin features (like `bitcoin-cli`).

        When using nix-bitcoin as part of a larger system config, it makes sense
        to set your main system user as the operator, by setting option
        `nix-bitcoin.operator.name = "MAIN_USER_NAME";`.
      '';
    };
    name = mkOption {
      type = types.str;
      default = "operator";
      description = "Name of the operator user.";
    };
    groups = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Extra groups of the operatur user.";
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
