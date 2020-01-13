{ pkgs }: with pkgs;

let
  generate-secrets = callPackage ./. {};
in
writeScript "make-secrets" ''
  # Update from old secrets format
  [[ -e secrets.nix ]] && . ${./update-secrets.sh}
  ${generate-secrets}
''
