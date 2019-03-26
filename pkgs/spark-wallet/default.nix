{ stdenv, pkgs, lib }:
lib.head (lib.attrValues (import ./composition.nix {
    inherit pkgs;
    inherit (stdenv.hostPlatform) system;
}))
