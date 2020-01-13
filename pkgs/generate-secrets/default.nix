{ pkgs }: with pkgs;

writeScript "generate-secrets" ''
  export PATH=${lib.makeBinPath [ coreutils apg openssl ]}
  . ${./generate-secrets.sh} ${./openssl.cnf}
''
