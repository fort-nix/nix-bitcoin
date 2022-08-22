{ pkgs ? import <nixpkgs> {} }:

import ./pkgs { inherit pkgs; }
