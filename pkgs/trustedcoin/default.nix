{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "trustedcoin";
  version = "0.8.4";

  src = fetchFromGitHub {
    owner = "nbd-wtf";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-mROWJEMRuIAcDXtEyin2+MLFplPInOsv5Q7vACNzi80=";
  };

  vendorHash = "sha256-fW+EoNPC0mH8C06Q6GXNwFdzE7oQT+qd+B7hGGml+hc=";

  subPackages = [ "." ];

  preCheck = ''
    ln -s $TMP/go/bin/trustedcoin .
  '';

  meta = with lib; {
    description = "Light bitcoin node implementation";
    homepage = "https://github.com/nbd-wtf/trustedcoin";
    maintainers = with maintainers; [ seberm fort-nix ];
    platforms = platforms.linux;
  };
}
