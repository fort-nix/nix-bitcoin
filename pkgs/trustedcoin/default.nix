{ lib, buildGo123Module, fetchFromGitHub }:

buildGo123Module rec {
  pname = "trustedcoin";
  version = "2024-11-15";

  src = fetchFromGitHub {
    owner = "nbd-wtf";
    repo = pname;
    rev = "92e6f2129f85548693b4a44b39eab9e5ade8c23d";
    hash = "sha256-Blw2s0JECe01s3Wn6gY3Ladd81+wWBBeXarICa0l/bU=";
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
