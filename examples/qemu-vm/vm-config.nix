{ modulesPath, ... }:
{
  # Disable the hardened preset to improve VM performance
  disabledModules = [ <nix-bitcoin/modules/presets/hardened.nix> ];

  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  config = {
    virtualisation.graphics = false;
    services.getty.autologinUser = "root";
    users.users.root = {
      openssh.authorizedKeys.keyFiles = [ ./id-vm.pub ];
    };
  };
}
