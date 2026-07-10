{ cdk
, pkgs
}:

let
  package = cdk.cdk-cli-static;
  arch = {
    x86_64-linux = "x86_64";
    aarch64-linux = "aarch64";
  }.${pkgs.stdenv.hostPlatform.system} or
    (throw "cdk-cli-static does not support ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.writeShellScriptBin "cdk-cli" ''
  exec ${package}/bin/cdk-cli-${package.version}-${arch} "$@"
''
