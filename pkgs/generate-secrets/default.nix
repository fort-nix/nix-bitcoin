{ pkgs }: with pkgs;

let
  rpcauth = pkgs.writeScriptBin "rpcauth" (builtins.readFile ./rpcauth/rpcauth.py);
in
writeScript "generate-secrets" ''
  export PATH=${lib.makeBinPath [ coreutils apg openssl gnugrep rpcauth python35 ]}
  . ${./generate-secrets.sh} ${./openssl.cnf}
''
