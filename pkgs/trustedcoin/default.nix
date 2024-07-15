{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "trustedcoin";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "nbd-wtf";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-M1z5Vn3UGLJHdCZxud8jM2ewiW90zzC7Vaidv3yGNAE=";
  };

  vendorHash = "sha256-hKaSB8/pymA7o2LuUpLjLZYn37JzEBn3a/3vkGbhLdM=";

  subPackages = [ "." ];

  meta = with lib; {
    description = "Light bitcoin node implementation";
    homepage = "https://github.com/nbd-wtf/trustedcoin";
    maintainers = with maintainers; [ seberm fort-nix ];
    platforms = platforms.linux;
  };
}
