{ stdenv, pkgs, lib }:
lib.head (builtins.attrValues (import ./composition.nix {
    inherit pkgs;
    inherit (stdenv.hostPlatform) system;
}))
