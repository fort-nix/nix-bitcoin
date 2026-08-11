# FIXME:
# Remove this file, along with the imports in ../../dev/dev.sh,
# ../../examples/container/flake.nix, ../../examples/deploy-container.sh and
# ./make-test.nix, as soon as extra-container declares these options itself
# (https://github.com/erikarvstedt/extra-container/blob/master/eval-config.nix).
#
# extra-container evaluates the container host with a minimal module set to keep
# eval times low. NixOS 26.05 added references to the following options to
# `system/boot/systemd.nix`, which is part of that module set, while their
# declaring modules are not.
#
# The defaults match the ones from the declaring modules. Like extra-container's
# own dummy options, these declarations have no type because they only exist to
# make host eval succeed. They don't affect the resulting container units.

{ lib, pkgs, ... }: {
  options = {
    environment.variables = lib.mkOption { default = {}; };
    i18n.imperativeLocale = lib.mkOption { default = false; };
    services.openssh.enable = lib.mkOption { default = false; };
    system.nixos-init.package = lib.mkOption { default = pkgs.nixos-init; };
    time.timeZone = lib.mkOption { default = null; };
  };
}
