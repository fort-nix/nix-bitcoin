{ pkgs ? import <nixpkgs> {} }:

(import ./pkgs { inherit pkgs; }) // {
  modules = import ./modules;
}
