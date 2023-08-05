{ lib, buildGoModule, fetchFromGitHub, fetchpatch }:

buildGoModule rec {
  pname = "trustedcoin";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "nbd-wtf";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-UNQjxhAT0mK1In7vUtIoMoMNBV+0wkrwbDmm7m+0R3o=";
  };

  patches = [
    # https://github.com/nbd-wtf/trustedcoin/pull/22 required for regtest
    (fetchpatch {
      name = "add-regtest-support";
      url = "https://github.com/nbd-wtf/trustedcoin/commit/aba05c55ccbfc50785328f556be8a5bd46e76beb.patch";
      hash = "sha256-24mYyXjUMVSlr9IlaqaTVAPE6bxxScNgR8Bb3x2t90Y=";
    })
  ];

  vendorSha256 = "sha256-xvkK9rMQlXTnNyOMd79qxVSvhgPobcBk9cq4/YWbupY=";

  subPackages = [ "." ];

  meta = with lib; {
    description = "Light bitcoin node implementation";
    homepage = "https://github.com/nbd-wtf/trustedcoin";
    maintainers = with maintainers; [ seberm fort-nix ];
    platforms = platforms.linux;
  };
}
