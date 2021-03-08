{
  virtualisation.graphics = false;
  services.mingetty.autologinUser = "root";
  users.users.root = {
    openssh.authorizedKeys.keyFiles = [ ./id-vm.pub ];
  };
}
