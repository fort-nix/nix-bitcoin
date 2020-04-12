# This file exists only for backwards compatibility

{ lib, ... }:
{
   imports = [
     ./presets/secure-node.nix
     (lib.mkRemovedOptionModule [ "services" "nix-bitcoin" "enable" ] "Please directly import ./presets/secure-node.nix")
   ]
}
