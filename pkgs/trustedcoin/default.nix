{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "trustedcoin";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "nbd-wtf";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-uEJVxpNKInIroHf22GQs+0xzJCijtIo+6KOM2Yefu6o=";
  };

  vendorHash = "sha256-xvkK9rMQlXTnNyOMd79qxVSvhgPobcBk9cq4/YWbupY=";

  subPackages = [ "." ];

  meta = with lib; {
    description = "Light bitcoin node implementation";
    homepage = "https://github.com/nbd-wtf/trustedcoin";
    maintainers = with maintainers; [ seberm fort-nix ];
    platforms = platforms.linux;
  };
}
