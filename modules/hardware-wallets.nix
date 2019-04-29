{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hardware-wallets;
  dataDir = "/var/lib/hardware-wallets/";
  enabled = cfg.ledger || cfg.trezor;
in {
  options.services.hardware-wallets = {
    ledger = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the ledger udev rules will be installed.
      '';
    };
    trezor = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the trezor udev rules will be installed.
      '';
    };
    group = mkOption {
      type = types.string;
      default = "hardware-wallets";
      description = ''
        Group the hardware wallet udev rules apply to.
      '';
    };
  };

  config = mkMerge [
    {
      # Create group
      users.groups."${cfg.group}" = {};
    }
    (mkIf cfg.ledger {
      # Ledger Nano S according to https://github.com/LedgerHQ/udev-rules/blob/master/add_udev_rules.sh
      # Don't use rules from nixpkgs because we want to use our own group.
      services.udev.packages = lib.singleton (pkgs.writeTextFile {
        name = "ledger-udev-rules";
        destination = "/etc/udev/rules.d/20-ledger.rules";
        text = ''
          SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0001", MODE="0660", GROUP="${cfg.group}"
        '';
      });
    })
    (mkIf cfg.trezor {
      # Don't use rules from nixpkgs because we want to use our own group.
      services.udev.packages = lib.singleton (pkgs.writeTextFile {
        name = "trezord-udev-rules";
        destination = "/etc/udev/rules.d/52-trezor.rules";
        text = ''
          # TREZOR v1 (One)
          SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="${cfg.group}", TAG+="uaccess", SYMLINK+="trezor%n"
          KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="${cfg.group}", TAG+="uaccess"

          # TREZOR v2 (T)
          SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="${cfg.group}", TAG+="uaccess", SYMLINK+="trezor%n"
          SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="${cfg.group}", TAG+="uaccess", SYMLINK+="trezor%n"
          KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="${cfg.group}", TAG+="uaccess"
        '';
      });
      services.trezord.enable = true;
    })
  ];
}
