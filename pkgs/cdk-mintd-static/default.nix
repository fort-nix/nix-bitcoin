{ cdk
, pkgs
}:

let
  package = cdk.cdk-mintd-static;
  arch = {
    x86_64-linux = "x86_64";
    aarch64-linux = "aarch64";
  }.${pkgs.stdenv.hostPlatform.system} or
    (throw "cdk-mintd-static does not support ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.writeShellScriptBin "cdk-mintd" ''
  exec ${package}/bin/cdk-mintd-${package.version}-${arch} "$@"
''
