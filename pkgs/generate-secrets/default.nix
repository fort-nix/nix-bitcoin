{ pkgs }: with pkgs;

let
  rpcauthSrc = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/bitcoin/bitcoin/d6cde007db9d3e6ee93bd98a9bbfdce9bfa9b15b/share/rpcauth/rpcauth.py";
    sha256 = "189mpplam6yzizssrgiyv70c9899ggh8cac76j4n7v0xqzfip07n";
  };
  rpcauth = pkgs.writeScriptBin "rpcauth" ''
    exec ${pkgs.python35}/bin/python ${rpcauthSrc} "$@"
  '';
in
writeScript "generate-secrets" ''
  export PATH=${lib.makeBinPath [ coreutils apg openssl gnugrep rpcauth ]}
  . ${./generate-secrets.sh} ${./openssl.cnf}
''
