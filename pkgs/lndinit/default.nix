{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "lndinit";
  version = "0.1.3-beta";

  src = fetchFromGitHub {
    owner = "lightninglabs";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-sO1DpbppCurxr9g9nUl9Vx82FJK1mTcUw3rY1Fm1wEU=";
  };

  vendorSha256 = "sha256-xdxxixSabcuGzwCctHrP/RV/Z8sCQDmk2PU4j1u8MX8=";

  subPackages = [ "." ];

  meta = with lib; {
    description = "Wallet initializer utility for lnd";
    homepage = "https://github.com/lightninglabs/lndinit";
    license = licenses.mit;
    maintainers = with maintainers; [ earvstedt ];
  };
}
