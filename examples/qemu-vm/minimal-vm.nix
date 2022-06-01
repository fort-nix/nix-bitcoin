nix-bitcoin: pkgs: system:

rec {
  inherit (nix-bitcoin.inputs) nixpkgs;

  mkVMScript = vm: pkgs.writers.writeBash "run-vm" ''
    set -euo pipefail
    export TMPDIR=$(mktemp -d /tmp/nix-bitcoin-vm.XXX)
    trap "rm -rf $TMPDIR" EXIT
    export NIX_DISK_IMAGE=$TMPDIR/nixos.qcow2
    QEMU_OPTS="-smp $(nproc) -m 1500" ${vm}/bin/run-*-vm
  '';

  vm = (import "${nixpkgs}/nixos" {
    inherit system;
    configuration = {
      imports = [
        nix-bitcoin.nixosModules.default
        "${nix-bitcoin}/modules/presets/secure-node.nix"
      ];

      nix-bitcoin.generateSecrets = true;
      services.clightning.enable = true;
      # For faster startup in offline VMs
      services.clightning.extraConfig = "disable-dns";

      nixpkgs.pkgs = pkgs;
      virtualisation.graphics = false;
      services.getty.autologinUser = "root";
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    };
  }).vm;

  runVM = mkVMScript vm;
}
