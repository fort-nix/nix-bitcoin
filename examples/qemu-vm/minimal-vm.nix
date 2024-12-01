nix-bitcoin: pkgs: system:

rec {
  inherit (nix-bitcoin.inputs) nixpkgs;

  mkVMScript = vm: pkgs.writers.writeBash "run-vm" ''
    set -euo pipefail
    export TMPDIR=$(mktemp -d /tmp/nix-bitcoin-vm.XXX)
    trap 'rm -rf $TMPDIR' EXIT
    export NIX_DISK_IMAGE=$TMPDIR/nixos.qcow2

    # shellcheck disable=SC2211
    QEMU_OPTS="-smp $(nproc) -m 1500" ${vm}/bin/run-*-vm
  '';

  vm = (import (nixpkgs + "/nixos") {
    inherit system;
    configuration = { config, lib, modulesPath, ... }: {
      imports = [
        nix-bitcoin.nixosModules.default
        (nix-bitcoin + "/modules/presets/secure-node.nix")
        (modulesPath + "/virtualisation/qemu-vm.nix")
      ];

      virtualisation.graphics = false;

      nix-bitcoin.generateSecrets = true;
      services.clightning.enable = true;
      # disable-dns leads to faster startup in offline VMs
      services.clightning.extraConfig = ''
        disable-dns
      '';

      # Avoid lengthy build of the nixos manual
      documentation.nixos.enable = false;

      nixpkgs.pkgs = pkgs;
      services.getty.autologinUser = "root";
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];

      services.getty.helpLine = lib.mkAfter ''

        Welcome to nix-bitcoin!
        To explore running services, try the following commands:
          nodeinfo
          systemctl status bitcoind
          systemctl status clightning
          bitcoin-cli -getinfo
          lightning-cli getinfo
      '';

      # Power off VM when the user exits the shell
      systemd.services."serial-getty@".preStop = ''
        echo o >/proc/sysrq-trigger
      '';

      system.stateVersion = lib.mkDefault config.system.nixos.release;
    };
  }).config.system.build.vm;

  runVM = mkVMScript vm;
}
