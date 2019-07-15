{ pkgs ? import <nixpkgs> {} }:

let
  dotnet = pkgs.callPackage ./build-support/dotnet { };
in
{
  # 'lib', 'modules' and 'overlays' are special, see
  # https://github.com/nix-community/NUR for more.
  modules = import ./modules; # NixOS modules

  btcpayserver = pkgs.callPackage ./pkgs/btcpayserver {
    inherit dotnet;
  };

  nbxplorer = pkgs.callPackage ./pkgs/nbxplorer {
    inherit dotnet;
  };

  nodeinfo = pkgs.callPackage ./pkgs/nodeinfo { };
  banlist = pkgs.callPackage ./pkgs/banlist { };
  lightning-charge = pkgs.callPackage ./pkgs/lightning-charge { };
  nanopos = pkgs.callPackage ./pkgs/nanopos { };
  spark-wallet = pkgs.callPackage ./pkgs/spark-wallet { };
  electrs = (pkgs.callPackage ./pkgs/electrs { }).rootCrate.build;
  liquidd = pkgs.callPackage ./pkgs/liquidd { };
  hwi = pkgs.callPackage ./pkgs/hwi { };
}
