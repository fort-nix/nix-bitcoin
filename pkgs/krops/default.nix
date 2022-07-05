{ pkgs ? import <nixpkgs> {} }:

let
  src = pkgs.fetchgit {
    url = "https://cgit.krebsco.de/krops";
    rev = "1.26.2";
    sha256 = "0mzn213dh3pklvdzfpwi4nin4lncdap447zvl11j81r809jll76j";
  };
in {
  lib = import "${src}/lib";
  pkgs = rec {
    krops = pkgs.callPackage "${src}/pkgs/krops" { inherit populate; };
    populate = pkgs.callPackage "${src}/pkgs/populate" {};
  };
}
