{ pkgs ? import <nixpkgs> {} }:

let
  src = pkgs.fetchgit {
    url = https://cgit.krebsco.de/krops/;
    rev = "804c79a14dc8f81a602d31d5a1eed5f82b3f2457";
    sha256 = "1k20l7zqprsrm9s38xslr7190vssf4sjdprd9gh146hxlvln2qrf";
  };
in {
  lib = import "${src}/lib";
  pkgs = import "${src}/pkgs" {};
}
